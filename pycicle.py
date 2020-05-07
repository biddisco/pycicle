#  Copyright (c) 2017-2020 John Biddiscombe
#  Copyright (c) 2019      Peter Doak
#
#  Distributed under the Boost Software License, Version 1.0. (See accompanying
#  file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
#--------------------------------------------------------------------------
#--------------------------------------------------------------------------
# pycicle
# Python Continuous Integration Command Line Engine
# Simple tool to poll PRs/etc on github and spawn builds
#--------------------------------------------------------------------------
#--------------------------------------------------------------------------
from __future__ import absolute_import, division, print_function, unicode_literals
import requests
import github
import ssl
import os
import subprocess
import time
import sys
import re
import string
import random
import socket
import datetime
from   dateutil.relativedelta import relativedelta
import argparse
import shlex     # splitting strings whilst keeping quoted sections
import copy
from random import randint

from pycicle_params import PycicleParams

#--------------------------------------------------------------------------
# Convert a string of the form "option[opt]" into a pair [option,opt]
# if the string has no option[...] then return [option,option]
#--------------------------------------------------------------------------
def get_option_symbol(option):
    sym = re.findall('(.+)\[([^\[\]]*)\]?', option)
    if sym:
        pyc_p.debug_print('Searching option[symbol]: Found', option, ',', sym[0][0], ',', sym[0][1])
        return [sym[0][0], sym[0][1]]
    else:
        pyc_p.debug_print('Searching option[symbol]: Subst', option)
        return [option,option]

#--------------------------------------------------------------------------
# Class holder for an Option type
#--------------------------------------------------------------------------
class option_type:
    def __init__(self, name, values):
        self._name    = name
        self._values  = []
        self._symbols = []
        for val in values:
            opt_sym = get_option_symbol(val)
            self._values.append(opt_sym[0])
            self._symbols.append(opt_sym[1])
        self._dependencies = {}
        self.print_option()

    def string_repr(self, indent=0):
        indt    = ' '*indent
        string_ = 'Option object: ' + str(self._name) + ' values: ' \
        + str(self._values) + ' symbols: ' + str(self._symbols)
        for k,v in self._dependencies.items():
            for v in self._dependencies[k]:
                string_ += '\n' + indt + str(k) + ' : ' + v.string_repr(indent+4)
        return string_

    def print_option(self, indent=4):
        pyc_p.debug_print(self.string_repr(4))

    def __repr__(self):
        return self.string_repr(4)

    def can_override(self, commandline_options):
        if self._name in commandline_options:
            pyc_p.debug_print('command-line {:30s} (override) {:s} '.format(self._name, commandline_options[self._name]))
            self.override(commandline_options[self._name])
            self.print_option()

    def override(self, new_value):
        if new_value in self._values:
            index = self._values.index(new_value)
            pyc_p.debug_print('Overriding', new_value, 'using index', index)
            self._values  = [self._values[index]]
            self._symbols = [self._symbols[index]]
        else:
            pyc_p.debug_print('Replacing', new_value)
            opt_sym = get_option_symbol(new_value)
            self._values  = [opt_sym[0]]
            self._symbols = [opt_sym[1]]

    def add_choices(self, new_values):
        for new_value in new_values:
            if new_value not in self._values:
                opt_sym = get_option_symbol(new_value)
                self._values.append(opt_sym[0])
                self._symbols.append(opt_sym[1])

    def add_dependency(self, val, option, options):
        if val in self._dependencies:
            self._dependencies[val].append(option)
        else:
            self._dependencies[val] = [option]
        self.print_option()

    def add_dependency_inverse(self, val, option, options):
        for value in self._values:
            if val != value:
                if value in self._dependencies:
                    self._dependencies[value].append(option)
                else:
                    self._dependencies[value] = [option]
        self.print_option()

    def random_choice(self):
        cmake_option = {}
        index = randint(0, len(self._values)-1)
        cmake_option[self._name] = [self._values[index], self._symbols[index]]
        pyc_p.debug_print('Random choice', cmake_option[self._name], 'from', self._name, '=', self._values)
        for value in self._dependencies:
            if cmake_option[self._name][0] == value:
                for dependent in self._dependencies[value]:
                    cmake_option.update(dependent.random_choice())
        return cmake_option

#--------------------------------------------------------------------------
# Command line args
#--------------------------------------------------------------------------
def get_command_line_args():
    parser = argparse.ArgumentParser()

    #----------------------------------------------
    # project name
    #----------------------------------------------
    parser.add_argument('-P', '--project', dest='project',
                        help='Project name (case sensitive) used as root of config dir for settings')

    #----------------------------------------------
    # pre_ctest_commands
    # imagine your host does not have cmake installed at the system
    # level. You make need to load a module or set a export a path
    # here. Right now it just takes a string to be run in shell
    #----------------------------------------------
    parser.add_argument('--pre_ctest_commands', dest='pre_ctest_commands', type=str,
                        default=None, help='Pre ctest commands')

    #----------------------------------------------
    # enable/debug mode
    #----------------------------------------------
    parser.add_argument('-d', '--debug', dest='debug', action='store_true',
                        default=False, help="Enable debug mode (don't build etc)")

    #----------------------------------------------
    # enable/debug display mode
    #----------------------------------------------
    parser.add_argument('-D', '--debug-info', dest='debug_info', action='store_true',
                        default=False, help='Display extra debugging info (but build as normal)')

    #----------------------------------------------
    # force rebuild mode
    #----------------------------------------------
    parser.add_argument('-f', '--force', dest='force', action='store_true',
                        help='Force rebuild of active PRs on next check')

    #----------------------------------------------
    # basic access control
    #----------------------------------------------
    parser.add_argument('-a', '--access-control', dest='access_control', action='store_true',
                        help='On PRs whose last commit was authored by a org member or the user themselves will be built and tested.')

    #----------------------------------------------
    # set default path for pycicle work dir
    #----------------------------------------------
    home = str(os.path.expanduser('~'))
    pycicle_dir = os.environ.get('PYCICLE_ROOT', home + '/pycicle')
    parser.add_argument('-r', '--pycicle-root', dest='pycicle_dir',
                        default=pycicle_dir, help='pycicle root path/directory (local filesystem)')

    #--------------------------------------------------------------------------
    # github token used to authenticate access
    #--------------------------------------------------------------------------
    user_token = 'generate a token and paste it here, or set env var'
    user_token = os.environ.get('PYCICLE_GITHUB_TOKEN', user_token)
    parser.add_argument('-t', '--github-token', dest='user_token', type=to_unicode,
                        default=user_token, help='github token used to authenticate access')

    #--------------------------------------------------------------------------
    # Machines : get a list of machines to use for testing (env{PYCICLE_MACHINES})
    # use a space separated list of machine nicknames such as
    # -m greina daint jb-laptop
    # where the names corresond to the name.cmake files in the config dir
    #
    # TODO : add support for multiple machines and configs
    #--------------------------------------------------------------------------
    machines = {os.environ.get('PYCICLE_MACHINES', 'greina')}
    parser.add_argument('-m', '--machines', dest='machines', nargs='+',
                        default=machines, help='list of machines to use for testing')

    #--------------------------------------------------------------------------
    # CMake options
    #--------------------------------------------------------------------------
    parser.add_argument('-o', '--options', dest='cmake_options', type=str, nargs='+',
                        default=None, help='CMake options to use for build (overrides random generation)')

    #--------------------------------------------------------------------------
    # PR - when testing, limit checks to a single PR
    #--------------------------------------------------------------------------
    parser.add_argument('-p', '--pull-request', dest='pull_request', type=int,
                        default=0, help='A single PR number for limited testing')

    #--------------------------------------------------------------------------
    # Config dir if not in pycicle directory
    #--------------------------------------------------------------------------
    parser.add_argument('--config-path', dest='config_path',
                        default='...', help='pycicle config path if not pycicle/config')

    #--------------------------------------------------------------------------
    # only enable scraping to test github status setting
    #--------------------------------------------------------------------------
    parser.add_argument('-c', '--scrape-only', dest='scrape_only', action='store_true',
                        default=False, help="Only scrape results and set github status (no building)")

    #--------------------------------------------------------------------------
    # Disable setting of github status on PR's - useful when testing pycicle
    #--------------------------------------------------------------------------
    parser.add_argument('-n', '--no-status', dest='no_status', action='store_true',
                        default=False, help="Disable setting github status")

    #--------------------------------------------------------------------------
    # CDash Server
    #--------------------------------------------------------------------------
    parser.add_argument('--cdash-server', dest='cdash_server',
                        default=None, help='CDash server')

    #----------------------------------------------
    # set username for ssh access to remote machine
    #----------------------------------------------
    parser.add_argument('-s', '--ssh-user', dest='sshusername', type=to_unicode,
                        default=None, help='Specify ssh username for remote machine access')

    #----------------------------------------------
    # print summary of parse args
    #----------------------------------------------
    args = parser.parse_args()
    machine = args.machines[0]
    if args.config_path == '...':
        args.config_path = './config/'
    print('-' * 30)
    print('pycicle: project        :', args.project)
    print('pycicle: debug          :',
          'enabled (no build trigger commands will be sent)' if args.debug else 'disabled')
    print('pycicle: scrape-only    :', 'enabled' if args.scrape_only else 'disabled')
    print('pycicle: force          :', 'enabled' if args.force else 'disabled')
    print('pycicle: access_control :', args.access_control )
    print('pycicle: config_path    :', args.config_path)
    print('pycicle: path           :', args.pycicle_dir)
    print('pycicle: token          :', args.user_token)
    print('pycicle: machines       :', args.machines)
    print('pycicle: machine        :', machine, '(only 1 supported currently)')
    print('pycicle: ssh user       :', args.sshusername)
    print('pycicle: PR             :', args.pull_request)
    print('pycicle: cmake options  :', args.cmake_options)
    options = {}
    if args.cmake_options is not None:
        if len(args.cmake_options)>1:
            args.cmake_options = [segments.replace('-D','') for segments in args.cmake_options]
        else:
            args.cmake_options = [words.replace('-D','') for segments in args.cmake_options for words in shlex.split(segments)]
        print('pycicle: clean options :', args.cmake_options)
        for s in args.cmake_options:
            temp = s.split('=')
            options[temp[0]] = temp[1]
        print('pycicle: options map   :', options)
    # replace the args option string with the dictionary version of it
    args.cmake_options = options
    print('-' * 30)
    return args

#--------------------------------------------------------------------------
# debug print
#--------------------------------------------------------------------------
def debug_print(*text):
    print('debug: ', end='')
    for txt in text:
        print(txt, end=' ')
    print()

#--------------------------------------------------------------------------
# find all the simple options that are defined in the file
# the return from this is a Dictionary of options,
# key = option name, value = list of choices
#--------------------------------------------------------------------------
def get_options_from_file(config_file, options, commandline_options) :
    pyc_p.debug_print('Looking for options in', config_file)
    for line in open(config_file):
        m = re.findall('PYCICLE_CMAKE_OPTION' + '\((.+?)\)', line)
        n = re.findall('PYCICLE_CMAKE_BOOLEAN_OPTION' + '\((.+?)\)', line)
        o = re.findall('PYCICLE_CMAKE_DEPENDENT_OPTION\((.+?)\)', line)
        if m:
            pyc_p.debug_print('-'*30)
            p1 = re.findall('([^ ]+) +(.+)',   m[0]) # normal option
            if p1:
                name = p1[0][0]
                pyc_p.debug_print('Option found', name, '(values)', p1[0][1])
                # shlex split options in case strings have spaces
                options[name] = option_type(name, shlex.split(p1[0][1]))
        elif n:
            pyc_p.debug_print('-'*30)
            p2 = re.findall('([^ ]+) +"(.+)"', n[0]) # boolean option
            if p2:
                name = p2[0][0]
                pyc_p.debug_print('Boolean found', name, 'Shortcut', p2[0][1], '(values) ON/OFF')
                options[name] = option_type(name, ['ON['+p2[0][1]+']', 'OFF[]'])
        elif o:
            pyc_p.debug_print('-'*30)
            p3 = re.findall('([^ ]+) +"([^"]+)" +(.+)', o[0])
            if p3:
                name = p3[0][0].strip('"')
                val  = p3[0][1].strip('"') if not ' ' in p3[0][1] else p3[0][1].strip()
                sub  = shlex.split(p3[0][2].strip())
                pyc_p.debug_print('Dependent option found if', name, '==', val, '(sub-option)', sub)
                if name in options:
                    if sub[0] in options:
                        old_option = options.pop(sub[0], None)
                        new_option = copy.deepcopy(old_option)
                        pyc_p.debug_print('Adding inverse dependency')
                        options[name].add_dependency_inverse(val, old_option, options)
                        pyc_p.debug_print('Adding dependency')
                        new_option.override(sub[1])
                        options[name].add_dependency(val, new_option, options)
                        pyc_p.debug_print('Done dependency')
                    else:
                        new_option = option_type(sub[0], sub[1:])
                        options[name].add_dependency(val, new_option, options)
                    new_option.can_override(commandline_options)
        else:
            continue
        # see if commandline options override the value
        if name in options:
            options[name].can_override(commandline_options)
    return options

#--------------------------------------------------------------------------
# find all the simple options that are defined for the project
# the return from this is a Dictionary of options,
# key = option name, value = list of choices
# load options from project file first, then override any duplicates
# with ones from machine file (machine file outranks project file).
#--------------------------------------------------------------------------
def get_cmake_build_options(project, machine, commandline_options) :
    options = {}
    current_path = os.path.dirname(os.path.realpath(__file__))
    # get options from project file first
    pyc_p.debug_print('-'*30, '#project get_simple_options')
    config_file = current_path + '/config/' + project + '/' + project + '.cmake'
    get_options_from_file(config_file, options, commandline_options)

    # if machine file overrides options, update with new ones
    pyc_p.debug_print('-'*30, '#machine get_simple_options')
    config_file = current_path + '/config/' + project + '/' + machine + '.cmake'
    get_options_from_file(config_file, options, commandline_options)

    return options

#--------------------------------------------------------------------------
#
#--------------------------------------------------------------------------
def find_build_options(project, machine, commandline_options) :
    # get all options from project and machine config files
    options = get_cmake_build_options(project, machine, commandline_options)
    pyc_p.debug_print('Commandline options :', commandline_options)
    pyc_p.debug_print('-'*30)
    pyc_p.debug_print('CMake options       :', options)
    pyc_p.debug_print('-'*30)
    # choose random settings
    cmake_options = {}
    for option in options.items():
        cmake_options.update(option[1].random_choice())
    pyc_p.debug_print('-'*30)
    pyc_p.debug_print('Random cmake settings :', cmake_options)
    #
    cmake_string = ''
    cdash_string = ''
    for i in cmake_options.items():
        if (' ' in i[1]) or ('\'' in i[1]):
            cmake_string += '-D' + i[0] + '=' + '"{}"'.format(i[1][0]) + ' '
        else:
            cmake_string += '-D' + i[0] + '=' + i[1][0] + ' '
        if i[1][1]:
            if cdash_string:
                cdash_string += '-'  + i[1][1]
            else:
                cdash_string += i[1][1]

    pyc_p.debug_print('-'*30)
    pyc_p.debug_print('CDash string', cdash_string)
    pyc_p.debug_print('-'*30)
    pyc_p.debug_print('CMake string', cmake_string)
    pyc_p.debug_print('-'*30)
    return cmake_string, cdash_string

#--------------------------------------------------------------------------
# Format the host access command prefix for ssh if it is a remote machine
#--------------------------------------------------------------------------
def format_command(remote_ssh, sshusername):
    if 'local' not in remote_ssh:
        cmd = ['ssh', sshusername + remote_ssh]
    else:
        cmd = []
    return cmd

#--------------------------------------------------------------------------
# Execute a shell comand and display the output as it appears
# returns output as string list with empty lines removed
# if shellmode is true, the subprocess command can execute multiple
# bash commands using the usual ';' or '&&' chaining operators
#--------------------------------------------------------------------------
def run_command(cmd, debug=False, shellmode=False):
    try:
        output = []
        if debug:
            print('\n', '-' * 20, 'Debug\n\n', subprocess.list2cmdline(cmd))
        else:
            shell_string = '(Shell=True)' if shellmode else ''
            print('\n', '-' * 20, 'Executing ',shell_string, '\n\n', subprocess.list2cmdline(cmd))
            print('\n', '-' * 20, 'Output\n')
            if shellmode:
                cmd = ' '.join(cmd)
            process = subprocess.Popen(cmd,
                stderr=subprocess.STDOUT,
                stdout=subprocess.PIPE,
                shell=shellmode)
            for line in iter(process.stdout.readline, b''):
                templine = line.decode(sys.stdout.encoding).rstrip()
                sys.stdout.write(templine)
                output.append(templine)
        print('\n', '-' * 20, 'Finished execution')
    except Exception as ex:
        print('\n', '*' * 30, "Caught Exception from subprocess :\n", ex)
        print('\n', '*' * 30)

    return output

#--------------------------------------------------------------------------
# launch a command that will start one build
#--------------------------------------------------------------------------
def launch_build(machine, branch_id, branch_name, cmake_options, cdash_string) :
    """ Calls the dashboard script, possibly remotely
        pyc_p is a global PycicleParams object
        ToDo: make pycicle runner into a class to get control of variable scope lifecycle
    """
    remote_ssh   = pyc_p.get_setting_for_machine(args.project, machine, 'PYCICLE_MACHINE')
    pycicle_path = pyc_p.get_setting_for_machine(args.project, machine, 'PYCICLE_ROOT')
    remote_http  = pyc_p.get_setting_for_machine(args.project, machine, 'PYCICLE_HTTP')
    job_type     = pyc_p.get_setting_for_machine(args.project, machine, 'PYCICLE_JOB_LAUNCH')
    debug_mode   = 'ON' if (args.debug or args.debug_info) else 'OFF'
    pyc_p.debug_print('-'*30)
    pyc_p.debug_print('launching build', branch_id, branch_name, job_type)
    pyc_p.debug_print('-'*30)

    # This is a clumsy way to do this.
    # implies local default, should be explicit somewhere
    if job_type=='slurm':
        pyc_p.debug_print("slurm build:", args.project)
        script = 'dashboard_slurm.cmake'
    elif job_type=='pbs':
        pyc_p.debug_print("pbs build:", args.project)
        script = 'dashboard_pbs.cmake'
    elif job_type=='debug':
        pyc_p.debug_print("debug :", args.project)
        script = 'dashboard_debug.cmake'
    else:
        pyc_p.debug_print("direct build:", args.project)
        script = 'dashboard_script.cmake'

    cmd = format_command(remote_ssh, sshusername)
    # Setup the environment (often even cmake comes from a module)
    if args.pre_ctest_commands:
        cmd = cmd + (args.pre_ctest_commands).split() + [' && ']
    cmd = cmd + ['ctest', '--debug', '-S'] if args.debug else cmd + ['ctest', '-S']

    if 'local' not in remote_ssh:
        # sending lists of options over SSH requires escaping them
        cmake_options = cmake_options.replace('"','\\"')
        cmake_options = '\"' + cmake_options + '\"'
        config_path = pycicle_path + pyc_p.remote_config_path
        cmd = cmd + [pycicle_path + '/pycicle/' + script]
    else:
        # if we're local we assume the current context has the module setup
        pyc_p.debug_print("Local build working in:", os.getcwd())
        config_path = pyc_p.config_path
        cmd = cmd + [script]

    if github_organisation:
       cmd = cmd + [ '-DPYCICLE_GITHUB_ORGANISATION=' + github_organisation ]
    if github_userlogin:
       cmd = cmd + [ '-DPYCICLE_GITHUB_USER_LOGIN=' + github_userlogin ]

    if branch_name=='master':
        build_name = branch_name + '-' + cdash_string
    else:
        build_name = branch_id + '-' + branch_name + '-' + cdash_string

    cmd = cmd + [ '-DPYCICLE_ROOT='                + pycicle_path,
                  '-DPYCICLE_HOST='                + machine,
                  '-DPYCICLE_PROJECT_NAME='        + args.project,
                  '-DPYCICLE_CONFIG_PATH='         + config_path,
                  '-DPYCICLE_GITHUB_PROJECT_NAME=' + github_reponame,
                  '-DPYCICLE_PR='                  + branch_id,
                  '-DPYCICLE_BRANCH='              + branch_name,
                  '-DPYCICLE_RANDOM='              + random_string(10),
                  '-DPYCICLE_BASE='                + github_base,
                  '-DPYCICLE_DEBUG_MODE='          + debug_mode,
                  '-DPYCICLE_CMAKE_OPTIONS='       + cmake_options,
                  '-DPYCICLE_CDASH_STRING='        + cdash_string,
                  '-DCTEST_BUILD_NAME='            + build_name,

                  # These are to quiet warnings from ctest about unset vars
                  '-DCTEST_SOURCE_DIRECTORY=.',
                  '-DCTEST_BINARY_DIRECTORY=.',
                  '-DCTEST_COMMAND=":"' ]

    run_command(cmd, args.debug)

#--------------------------------------------------------------------------
# launch one build from a list of options
#--------------------------------------------------------------------------
def choose_and_launch(project, machine, branch_id, branch_name, cmake_options, num_builds) :
    print('Starting', num_builds, 'builds for PR', branch_id, branch_name)
    pyc_p.debug_print("Begin : choose_and_launch", project, machine, branch_id, branch_name, cmake_options)

    for build in range(0,int(num_builds)):
        # get options for build
        cmake_options_string, cdash_string = find_build_options(project, machine, cmake_options)
        launch_build(machine, branch_id, branch_name, cmake_options_string, cdash_string)

#--------------------------------------------------------------------------
# Utility function to remove a file from a remote filesystem
#--------------------------------------------------------------------------
def erase_file(remote_ssh, file):
    # erase the pycicle scrape file if we have set status corectly
    cmd = format_command(remote_ssh, sshusername)
    cmd = cmd + [ 'rm', '-f', file]
    run_command(remote_ssh, cmd, args.debug)
    print('File removed', file)

#--------------------------------------------------------------------------
# find all the PR build jobs submitted and from them the build dirs
# that we can use to scrape results from
#--------------------------------------------------------------------------
def find_scrape_files(project, machine) :
    remote_ssh  = pyc_p.get_setting_for_machine(project, machine, 'PYCICLE_MACHINE')
    remote_path = pyc_p.get_setting_for_machine(project, machine, 'PYCICLE_ROOT')

    JobFiles   = []
    PR_numbers = {}
    #
    cmd = format_command(remote_ssh, sshusername)
    try:
        search_path = remote_path + '/build/'
        print("Scraping in {}.".format(search_path))
        cmd = cmd + [ 'find', search_path,
                      '-maxdepth',  '2',
                      '-path', '\'' + search_path + project + '-*' + '\'',
                      '-name', 'pycicle-TAG.txt']

        result = run_command(cmd, args.debug)
        print(result)

        for tagfile in result:
            JobFiles.append(tagfile)
            pyc_p.debug_print('Processing', tagfile)
            # for each build dir, return the PR number and results file
            m = re.search(search_path + project + '-([0-9]+).*/pycicle-TAG.txt', tagfile)
            if m:
                pyc_p.debug_print('Regex search pycicle-TAG gives PR:', m.group(1))
                # create default empty list (if needed) and then add item to list
                PR_numbers.setdefault(m.group(1), []).append(tagfile)

    except Exception as e:
        print("Exception", e, " : "
            "find_scrape_files failed for {}".format(search_path))
    return PR_numbers

#--------------------------------------------------------------------------
# collect test results so that we can update github PR status
#--------------------------------------------------------------------------
def scrape_testing_results(project, machine, scrape_file, branch_id, branch_name, head_commit) :
    remote_ssh  = pyc_p.get_setting_for_machine(project, machine, 'PYCICLE_MACHINE')

    cmd = format_command(remote_ssh, sshusername)
    cmd = cmd + [ 'cat', scrape_file ]

    Config_Errors = 0
    Build_Errors  = 0
    Test_Errors   = 0
    Errors        = []

    context = re.search(r'/build/'+project+'-.+?-(.+)/pycicle-TAG.txt', scrape_file)
    if context:
        origin = machine + '-' + context.group(1)
    else:
        origin = 'unknown'

    result = run_command(cmd, args.debug)
    for s in result:
        Errors.append(s)
    print('Config/Build/Test Errors are', Errors)

    Config_Errors = int(Errors[0])
    Build_Errors  = int(Errors[1])
    Test_Errors   = int(Errors[2])
    StatusValid   = True if len(Errors)>3 else False
    if StatusValid:
        DateStamp = Errors[3]
        DateURL   = DateStamp[0:4]+'-'+DateStamp[4:6]+'-'+DateStamp[6:8]
        print('Extracted date as', DateURL)

        URL = ('{}://{}/{}/index.php?project='.format(cdash_drop_method, cdash_server, cdash_http_path) + cdash_project_name +
               '&date=' + DateURL +
               '&filtercount=1' +
               '&field1=buildname/string&compare1=63&value1=' +
               branch_id + '-' + branch_name)
        print("URL:", URL)
        if args.debug:
            print('Debug github PR status', URL)
        elif args.no_status:
            print('Disabled github PR status setting', URL)
        else:
            head_commit.create_status(
                'success' if Config_Errors==0 else 'failure',
                target_url=URL,
                description='errors ' + Errors[0],
                context='pycicle ' + origin + ' Config')
            head_commit.create_status(
                'success' if Build_Errors==0 else 'failure',
                target_url=URL,
                description='errors ' + Errors[1],
                context='pycicle ' + origin + ' Build')
            head_commit.create_status(
                'success' if Test_Errors==0 else 'failure',
                target_url=URL,
                description='errors ' + Errors[2],
                context='pycicle ' + origin + ' Test')
            print('Done setting github PR status for', origin)

    erase_file(remote_ssh, scrape_file)
    print('-' * 30)

#--------------------------------------------------------------------------
# random string of N chars
#--------------------------------------------------------------------------
def random_string(N):
    return ''.join(random.choice(string.ascii_uppercase + string.digits)
        for _ in range(N))

#--------------------------------------------------------------------------
# Check if a PR Needs and Update
#--------------------------------------------------------------------------
def needs_update(project_name, branch_id, branch_name, branch_sha, base_sha):
    directory     = args.pycicle_dir + '/src/' + project_name + '-' + branch_id
    status_file   = directory + '/last_pr_sha.txt'
    update        = False
    #
    pyc_p.debug_print("Begin : needs_update", directory)
    if os.path.exists(directory) == False:
        os.makedirs(directory)
        pyc_p.debug_print("Created ", directory)
        update = True
    else:
        try:
            f = open(status_file,'r')
            lines = f.readlines()
            if lines[0].strip() != branch_sha:
                print(branch_id, branch_name, 'changed : trigger update')
                update = True
            elif (lines[1].strip() != base_sha):
                print('base branch changed : trigger update')
                update = True
            f.close()
        except:
            print(branch_id, branch_name, 'status error : trigger update')
            update = True
    #
    if update:
        f = open(status_file,'w')
        f.write(branch_sha + '\n')
        f.write(base_sha + '\n')
        f.close()
    #
    return update

#--------------------------------------------------------------------------
# Delete old build and src dirs from pycicle root
#--------------------------------------------------------------------------
def delete_old_files(machine, path, days) :
    remote_ssh  = pyc_p.get_setting_for_machine(args.project, machine, 'PYCICLE_MACHINE')
    remote_path = pyc_p.get_setting_for_machine(args.project, machine, 'PYCICLE_ROOT')
    directory   = remote_path + '/' + path
    Dirs        = []

    cmd1 = format_command(remote_ssh, sshusername)
    cmd = cmd1 + ['find', directory,
        '-mindepth', '1', '-maxdepth', '1', '-type', 'd', '-mtime', '+' + str(days)]

    result = run_command(cmd, args.debug)

    for s in result:
        cmd = cmd1 + [ 'rm', '-rf', s]
        print('Deleting old/stale directory : ', s)
        run_command(cmd, args.debug)

def git_login(github_organisation, github_userlogin):
    if github_organisation:
        print("github init     : ({},{})".format(github_organisation, args.user_token))
        git  = github.Github(github_organisation, args.user_token)
    elif github_userlogin:
        print("github init     : ({},{})".format(github_userlogin, args.user_token))
        git = github.Github(github_userlogin, args.user_token)
    elif args.user_token:
        print("github init     : ({})".format(args.user_token))
        git = github.Github(args.user_token)
    else:
        print('github init     : No login mode specified')
    if not github_userlogin:
        github_userlogin = git.get_user().login
    print("Github Login    :",git.get_user().login)
    print("Github (User)   :",github_userlogin)
    print("Github Reponame :",github_reponame)
    return git

#--------------------------------------------------------------------------
# main program starts here
#--------------------------------------------------------------------------
if __name__ == "__main__":
    #--------------------------------------------------------------------------
    # Fix unicode python 2 and python 3 problem with argument parsing
    #--------------------------------------------------------------------------
    try:
        unicode
    except NameError:
        # Define `unicode` for Python3
        def unicode(s, *_):
            return s

    def to_unicode(s):
        return unicode(s, "utf-8")

    args = get_command_line_args()
    machine = args.machines[0]

    # Definitions:
    # args are what are passed in at the command line
    # config are what are read from file
    # params are what pycicle actually runs with

    # new params object PycicleParams to start rationalizing
    # args vs. config. and assist reading part of config from
    # project repos themselves.

    if args.debug or args.debug_info:
        pyc_p = PycicleParams(args, debug_print=debug_print)
    else:
        pyc_p = PycicleParams(args)

    #--------------------------------------------------------------------------
    # Create a Github instance:
    #--------------------------------------------------------------------------
    github_reponame     = pyc_p.get_setting_for_project(args.project, machine, 'PYCICLE_GITHUB_PROJECT_NAME')
    github_organisation = pyc_p.get_setting_for_project(args.project, machine, 'PYCICLE_GITHUB_ORGANISATION')
    github_userlogin    = pyc_p.get_setting_for_machine_project(args.project, machine, 'PYCICLE_GITHUB_USER_LOGIN')
    github_base         = pyc_p.get_setting_for_project(args.project, machine, 'PYCICLE_GITHUB_BASE_BRANCH')
    if args.cdash_server:
        cdash_server = args.cdash_server
    else:
        cdash_server    = pyc_p.get_setting_for_project(args.project, machine, 'PYCICLE_CDASH_SERVER_NAME')
    cdash_project_name  = pyc_p.get_setting_for_project(args.project, machine, 'PYCICLE_CDASH_PROJECT_NAME')
    cdash_drop_method   = pyc_p.get_setting_for_machine(args.project, machine, 'PYCICLE_CDASH_DROP_METHOD')
    cdash_http_path     = pyc_p.get_setting_for_project(args.project, machine, 'PYCICLE_CDASH_HTTP_PATH')
    if not cdash_drop_method:
        cdash_drop_method = "https"
    builds_per_pr_str   = pyc_p.get_setting_for_machine_project(args.project, machine, 'PYCICLE_BUILDS_PER_PR')
    builds_per_pr       = int(builds_per_pr_str)
    if args.sshusername:
        sshusername = args.sshusername + '@'
    else:
        sshusername = ''
    pyc_p.debug_print('-' * 30)
    print('PYCICLE_GITHUB_PROJECT_NAME  =', github_reponame)
    if github_organisation:
        print('PYCICLE_GITHUB_ORGANISATION  =', github_organisation)
    else:
        print('PYCICLE_GITHUB_USER_LOGIN    =', github_userlogin)
    print('PYCICLE_GITHUB_BASE_BRANCH   =', github_base)
    print('PYCICLE_CDASH_PROJECT_NAME   =', cdash_project_name)
    print('PYCICLE_CDASH_SERVER_NAME    =', cdash_server)
    print('PYCICLE_CDASH_HTTP_PATH      =', cdash_http_path)
    print('PYCICLE_CDASH_DROP_METHOD    =', cdash_drop_method)
    print('PYCICLE_BUILDS_PER_PR        =', builds_per_pr)

    #--------------------------------------------------------------------------
    # @todo make these into options
    # 60 seconds between polls.
    poll_time   = 60
    # 10 mins between checks for results and cleanups.
    scrape_time = 10*60
    #
    random.seed()
    #

    org = None

    try:        
        git = git_login(github_organisation, github_userlogin)
        try:
            if github_organisation:
                org = git.get_organization(github_organisation)
                print("Organisation    :", org.login, org.name)
                repo = org.get_repo(github_reponame)
            else:
                print("Getting Repo    :", github_userlogin + '/' + github_reponame)
                repo = git.get_repo(github_userlogin + '/' + github_reponame)
        except github.UnknownObjectException as ukoe:
            print("Exception     : Trying to recover from organization passed as name")
            git  = github.Github(args.user_token)
            repo = git.get_repo(github_reponame)
            print(vars(repo))
        except Exception as ex:
            print("unexpected exception caught in github connect:",ex)
        print("Repo Fullname   :", repo.full_name)
    except Exception as e:
        print(e, 'Failed to connect to github. Network down?')

    if github_base == '':
        github_base = repo.default_branch

    #--------------------------------------------------------------------------
    pyc_p.debug_print("Before main polling routine github_base:", github_base)

    #--------------------------------------------------------------------------
    # main polling routine
    #--------------------------------------------------------------------------
    #
    startuptime     = datetime.datetime.now()
    github_t1       = startuptime
    scrape_t1       = startuptime + datetime.timedelta(hours=-1)
    scrape_tdiff    = 0
    force           = args.force
    #
    while True:
        #
        try:
            github_t2     = datetime.datetime.now()
            github_tdiff  = github_t2 - github_t1
            github_t1     = github_t2
            uptime        = relativedelta(github_t2, startuptime)
            print('-' * 30)
            print(f'Checking github - elapsed = {github_tdiff.seconds}s : '
                  f'Uptime = {uptime.years:02}Y:{uptime.months:02}M:{uptime.days:02}D {uptime.hours:02}h:{uptime.minutes:02}m:{uptime.seconds:02}s')
            print('-' * 30)

            try:
                base_branch = repo.get_branch(github_base) #should be PYCICLE_BASE
                base_sha    = base_branch.commit.sha
                pyc_p.debug_print(base_branch)

            except requests.exceptions.ConnectionError as ex:
                # github might have closed the connection after a long delay
                # so we will reconnect using the same credentials as before
                print('Github ConnectionError:', ex)
                git = git_login(github_organisation, github_userlogin)

            #
            pull_requests = []
            # just get a single PR if that was all that was asked for
            if args.pull_request>0:
                pyc_p.debug_print('Getting PR', args.pull_request)
                try:
                    pr = repo.get_pull(args.pull_request)
                except Exception as ex:
                    pyc_p.debug_print('Could not get PR - is it valid?:', ex)
                    break
                pyc_p.debug_print(pr)
                pull_requests = [pr]
                pyc_p.debug_print('Requested PR: ', pr)
            # -1 means only master/base branch
            elif args.pull_request==-1:
                print("Building only",base_branch.name)
            # otherwise get all open PRs
            else:
                print("Getting open PR's for ",base_branch.name)
                pull_requests = repo.get_pulls('open', base=base_branch.name)

            pr_list = {}
            #
            for pr in pull_requests:
                # find out if the PR is from a local branch or from a clone of the repo
                try:
                    pyc_p.debug_print('-' * 30)
                    pyc_p.debug_print(pr)
                    pyc_p.debug_print('Repo to merge from   :', pr.head.repo.owner.login)
                    pyc_p.debug_print('Branch to merge from :', pr.head.ref)

                    if pr.head.repo.owner.login==github_organisation:
                        pyc_p.debug_print('Pull request is from branch local to repo')
                    else:
                        pyc_p.debug_print('Pull request is from branch of forked repo')
                    pyc_p.debug_print('git pull https://github.com/' + pr.head.repo.owner.login
                                      + '/' + github_reponame + '.git' + ' ' + pr.head.ref)
                    pyc_p.debug_print('-' * 30)
                except Exception as ex:
                    pyc_p.debug_print('Could not get information about PR source repo:', ex)
                    continue

                branch_id   = str(pr.number)
                branch_name = pr.head.label.rsplit(':',1)[1]
                short_name  = (branch_name[:14] + '..') if len(branch_name) > 16 else branch_name
                pyc_p.debug_print('Branch short name    :', short_name)
                branch_sha  = pr.head.sha
                # need details, including last commit on PR for setting status
                last_pr_commit = pr.get_commits().reversed[0]
                pr_list[branch_id] = [machine, branch_name, last_pr_commit]
                #
                if args.pull_request!=0 and pr.number!=args.pull_request:
                    continue
                if not pr.mergeable:
                    pyc_p.debug_print('Skipping PR - not mergeable')
                    continue
                #
                if not args.scrape_only:
                    #minimal security, only if last commit by org members or owner is it updated or built.   
                    commit_author = last_pr_commit.author
                    update = force or needs_update(args.project, branch_id, branch_name, branch_sha, base_sha)
                    if args.access_control:
                        if org:
                            if org.has_in_members(commit_author):
                                if update:
                                    choose_and_launch(args.project, machine, branch_id, branch_name, compiler_type)
                            else:
                                print("{} is not a member of the organisation, PR will not be built.".format(commit_author.login))
                        else:
                            permission = repo.get_collaborator_permission(commit_author)
                            if 'push' in permission:
                                if update:
                                    choose_and_launch(args.project, machine, branch_id, short_name, args.cmake_options, builds_per_pr)
                            else:
                                print("{} does not have push access, PR will not be built.".format(commit_author.login))
                    elif update:
                        choose_and_launch(args.project, machine, branch_id, short_name, args.cmake_options, builds_per_pr)

            print("The Open PRs:")
            print(pr_list)
            # also build the base branch if it has changed
            if not args.scrape_only and args.pull_request<=0:
                if force or needs_update(args.project, github_base, github_base, base_sha, base_sha):
                    choose_and_launch(args.project, machine, github_base, github_base, args.cmake_options, builds_per_pr)
                    pr_list[github_base] = [machine, github_base, base_branch.commit, ""]

            scrape_t2    = datetime.datetime.now()
            scrape_tdiff = scrape_t2 - scrape_t1
            if (scrape_tdiff.seconds > scrape_time):
                scrape_t1 = scrape_t2
                print('Scraping results:', 'Time since last check', scrape_tdiff.seconds, '(s)')
                builds_done = find_scrape_files(args.project, machine)
                print('scrape files for PRs', builds_done)
                for branch_id, tagfiles in builds_done.items():
                    if branch_id in pr_list:
                        for tagfile in tagfiles:
                            # machine, scrape_file, branch_id, branch_name, head_commit
                            scrape_testing_results(
                                args.project,
                                pr_list[branch_id][0], tagfile,
                                branch_id, pr_list[branch_id][1], pr_list[branch_id][2])
                    else:
                        # just delete the file, it is probably an old one
                        erase_file(
                            pyc_p.get_setting_for_machine(args.project, machine, 'PYCICLE_MACHINE'),
                            builds_done.get(branch_id))

                # cleanup old files that need to be purged every N days
                delete_old_files(machine, 'src',   1)
                delete_old_files(machine, 'build', 1)

        except (github.GithubException, socket.timeout, ssl.SSLError) as ex:
            # github might be down, or there may be a network issue,
            # just go to the sleep statement and try again in a minute
            print('Github/Socket exception :', ex)

        # Sleep for a while before polling github again
        time.sleep(poll_time)
        # force option should only have effect on the first iteration
        force = False
