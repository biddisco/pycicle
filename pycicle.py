#  Copyright (c) 2018      Peter Doak
#  Copyright (c) 2017-2018 John Biddiscombe
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
                        default=None, help="Pre ctest commands")

    #----------------------------------------------
    # enable/debug mode
    #----------------------------------------------
    parser.add_argument('-d', '--debug', dest='debug', action='store_true',
                        default=False, help="Enable debug mode (don't build etc)")

    #----------------------------------------------
    # enable/debug display mode
    #----------------------------------------------
    parser.add_argument('-D', '--debug-info', dest='debug_info', action='store_true',
                        default=False, help="Display extra debugging info (but build as normal)")

    #----------------------------------------------
    # force rebuild mode
    #----------------------------------------------
    parser.add_argument('-f', '--force', dest='force', action='store_true',
                        default=False, help="Force rebuild of active PRs on next check")

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
                        help='CDash server', default=None)

    #----------------------------------------------
    # print summary of parse args
    #----------------------------------------------
    args = parser.parse_args()
    machine = args.machines[0]

    print('-' * 30)
    print('pycicle: project       :', args.project)
    print('pycicle: debug         :',
          'enabled (no build trigger commands will be sent)' if args.debug else 'disabled')
    print('pycicle: scrape-only   :', 'enabled' if args.scrape_only else 'disabled')
    print('pycicle: force         :', 'enabled' if args.force else 'disabled')
    print('pycicle: path          :', args.pycicle_dir)
    print('pycicle: token         :', args.user_token)
    print('pycicle: machines      :', args.machines)
    print('pycicle: machine       :', machine, '(only 1 supported currently)')
    print('pycicle: PR            :', args.pull_request)
    print('pycicle: cmake options :', args.cmake_options)
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
<<<<<<< Updated upstream
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
=======
                options[p[0][0]] = shlex.split(p[0][1])
                if p[0][0] in commandline_options:
                    pyc_p.debug_print('command-line {:30s} (override) {:s} '.format(p[0][0], commandline_options[p[0][0]][0]))
                    options[p[0][0]] = commandline_options[p[0][0]]
                options_symbols = []
                for opt in options[p[0][0]]:
                    options_symbols += [get_option_symbol(opt)]
                # replace original choice strings with parsed [opt,sym] pairs
                options[p[0][0]] = options_symbols

    return options

def get_boolean_options_file(config_file, reg_string, commandline_options) :
    pyc_p.debug_print('Looking for options in', config_file)
    f = open(config_file)

    regex = reg_string + '\((.+?)\)'
    options = {}
    for line in f:
        m = re.findall(regex, line)
        if m:
            p = re.findall('([^ ]+) +"(.+)"', m[0])
            if p:
                pyc_p.debug_print('Boolean found {:30s} Shortcut {:s} (values) ON/OFF'.format(p[0][0], p[0][1]))
                # shlex in case string has spaces
                options[p[0][0]] = [[str('ON'),p[0][1]], [str('OFF'),str('')]]
                if p[0][0] in commandline_options:
                    pyc_p.debug_print('command-line {:30s} (override) {:s} '.format(p[0][0], commandline_options[p[0][0]][0]))
                    options[p[0][0]] = [get_option_symbol(commandline_options[p[0][0]])]
    return options

#--------------------------------------------------------------------------
# find all the dependent options that are defined in the file
# the return from this is a Dictionary of options,
# key = option name, value = list of choices
#--------------------------------------------------------------------------
def get_dependent_options_file(config_file, reg_string, commandline_options) :
    pyc_p.debug_print('Looking for dependent options in', config_file)
    f = open(config_file)

    regex = reg_string + '*\((.+?)\)'
    options = []
    for line in f:
        m = re.findall(regex, line)
        if m:
            p = re.findall('([^ ]+) +"([^"]+)" +(.+)', m[0])
            if p:
                opt = p[0][0].strip('"')
                val = p[0][1].strip('"') if not ' ' in p[0][1] else p[0][1].strip()
                sub = p[0][2].strip()
                pyc_p.debug_print('Dependent option found {:30s} (value) {:15s} (sub-option) {:s}'.format(opt, val, sub))
                subopt = {}
                sub_list = shlex.split(sub)
                subopt[val] = sub_list
                if sub_list[0] in commandline_options:
                    new_list = [sub_list[0], commandline_options[sub_list[0]]]
                    pyc_p.debug_print('command-line overrides {:30s} (value) {:15s}'.format(new_list[0], new_list[1]))
                    subopt[val] = new_list
                options.append([opt, subopt])
>>>>>>> Stashed changes
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
# Execute a shell comand and display the output as it appears
#--------------------------------------------------------------------------
def run_command(cmd, debug=False):
    try:
        if debug:
            print('\n', '-' * 20, 'Debug\n', subprocess.list2cmdline(cmd))
        else:
            print('\n', '-' * 20, 'Executing\n', subprocess.list2cmdline(cmd))
            print('\n', '-' * 30)
            process = subprocess.Popen(cmd,
                stderr=subprocess.STDOUT,
                stdout=subprocess.PIPE)
            for line in iter(process.stdout.readline, b''):
                sys.stdout.write(line.decode(sys.stdout.encoding))
        print('\n', '-' * 30, 'Finished execution')
    except Exception as ex:
        print('\n', '*' * 30, "Caught Exception from subprocess :\n", ex)
        print('\n', '*' * 30)

#--------------------------------------------------------------------------
# launch a command that will start one build
#--------------------------------------------------------------------------
def launch_build(machine, branch_id, branch_name, cmake_options, cdash_string) :
    remote_ssh  = pyc_p.get_setting_for_machine(args.project, machine, 'PYCICLE_MACHINE')
    remote_path = pyc_p.get_setting_for_machine(args.project, machine, 'PYCICLE_ROOT')
    remote_http = pyc_p.get_setting_for_machine(args.project, machine, 'PYCICLE_HTTP')
    job_type    = pyc_p.get_setting_for_machine(args.project, machine, 'PYCICLE_JOB_LAUNCH')
    debug_mode  = 'ON' if (args.debug or args.debug_info) else 'OFF'
    pyc_p.debug_print('-'*30)
    pyc_p.debug_print('launching build', branch_id, branch_name, job_type)
    pyc_p.debug_print('-'*30)
<<<<<<< Updated upstream
=======
    pyc_p.debug_print(cmake_options)
    pyc_p.debug_print('-'*30)

    options_hash = hash_options_string(cmake_options)
    print('Options hash :', options_hash)
>>>>>>> Stashed changes

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

    if 'local' not in remote_ssh:
        # We need to setup the environment on the remote machine,
        # often even cmake comes from a module or the like.
        org_dir = '.'
        cmd1 = []
        if args.pre_ctest_commands:
            cmd1.append(args.pre_ctest_commands)
        cmd1.append('ctest')
        cmd1 = ' '.join(cmd1)
        cmd = ['ssh', remote_ssh, cmd1, '-S',
               remote_path  + '/pycicle/' + script ]
        # sending lists of options over SSH requires escaping them
        cmake_options = cmake_options.replace('"','\\"')
        cmake_options = '\"' + cmake_options + '\"'
    else:
        # if we're local we assume the current context has the module setup
        pyc_p.debug_print("Local build working in:", os.getcwd())
        cmd = ['ctest','-S', script ]

    cmd = cmd + [ '-DPYCICLE_ROOT='                + remote_path,
                  '-DPYCICLE_HOST='                + machine,
                  '-DPYCICLE_PROJECT_NAME='        + args.project,
                  '-DPYCICLE_GITHUB_PROJECT_NAME=' + github_reponame,
                  '-DPYCICLE_GITHUB_ORGANISATION=' + github_organisation,
                  '-DPYCICLE_PR='                  + branch_id,
                  '-DPYCICLE_BRANCH='              + branch_name,
                  '-DPYCICLE_RANDOM='              + random_string(10),
                  '-DPYCICLE_BASE='                + github_base,
                  '-DPYCICLE_DEBUG_MODE='          + debug_mode,
                  '-DPYCICLE_CMAKE_OPTIONS='       + cmake_options,
                  '-DPYCICLE_CDASH_STRING='        + cdash_string,
                  # These are to quiet warnings from ctest about unset vars
                  '-DCTEST_SOURCE_DIRECTORY=.',
                  '-DCTEST_BINARY_DIRECTORY=.',
                  '-DCTEST_COMMAND=":"' ]

    run_command(cmd, args.debug)
    return None

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
    if 'local' not in remote_ssh:
        cmd = ['ssh', remote_ssh ]
    else:
        cmd = []
    cmd = cmd + [ 'rm', '-f', file]
    run_command(cmd)
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
    try:
        if 'local' not in remote_ssh:
            cmd = ['ssh', remote_ssh ]
        else:
            cmd = []

        search_path = remote_path + '/build/'
        cmd = cmd + [ 'find', search_path,
                      '-maxdepth',  '2',
                      '-path', '\'' + search_path + project + '-*' + '\'',
                      '-name', 'pycicle-TAG.txt']

        pyc_p.debug_print('executing', cmd)
        result = subprocess.check_output(cmd).splitlines()
        pyc_p.debug_print('find pycicle-TAG using', cmd, 'gives :\n', result)
        for s in result:
            tagfile = s.decode('utf-8')
            JobFiles.append(tagfile)
            pyc_p.debug_print('#'*5, tagfile)
            # for each build dir, return the PR number and results file
            m = re.search(search_path + project + '-([0-9]+).*/pycicle-TAG.txt', tagfile)
            if m:
                PR_numbers[m.group(1)] = tagfile
                pyc_p.debug_print('#'*5, 'Regex search pycicle-TAG gives PR:', m.group(1))

    except Exception as e:
        print("Exception", e, " : "
            "find_scrape_files failed for {}".format(search_path))
    return PR_numbers

#--------------------------------------------------------------------------
# collect test results so that we can update github PR status
#--------------------------------------------------------------------------
def scrape_testing_results(project, machine, scrape_file, branch_id, branch_name, head_commit) :
    remote_ssh  = pyc_p.get_setting_for_machine(project, machine, 'PYCICLE_MACHINE')

    if 'local' not in remote_ssh:
        cmd = ['ssh', remote_ssh ]
    else:
        cmd = []
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

    try:
        result = subprocess.check_output(cmd).split()
        for s in result: Errors.append(s.decode('utf-8'))
        print('Config/Build/Test Errors are', Errors)

        Config_Errors = int(Errors[0])
        Build_Errors  = int(Errors[1])
        Test_Errors   = int(Errors[2])
        StatusValid   = True if len(Errors)>3 else False
        if StatusValid:
            DateStamp = Errors[3]
            DateURL   = DateStamp[0:4]+'-'+DateStamp[4:6]+'-'+DateStamp[6:8]
            print('Extracted date as', DateURL)

            URL = ('http://{}/{}/index.php?project='.format(cdash_server, cdash_http_path) + cdash_project_name +
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

    except Exception as ex:
        print('Scrape failed for PR', branch_id, ex)

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

    if 'local' not in remote_ssh:
        cmd_transport = ['ssh', remote_ssh ]
    else:
        cmd_transport = []
    cmd = cmd_transport + ['find', directory,
        '-mindepth', '1', '-maxdepth', '1', '-type', 'd', '-mtime', '+' + str(days)]

    pyc_p.debug_print('Cleanup find:', cmd)
    try:
        result = subprocess.check_output(cmd).split()
        for s in result:
            temp = s.decode('utf-8')
            cmd = cmd_transport + [ 'rm', '-rf', temp]
            print('Deleting old/stale directory : ', temp)
            result = subprocess.check_output(cmd).split()
    except Exception as ex:
        print('Cleanup failed for ', machine, ex)


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
    github_base         = pyc_p.get_setting_for_project(args.project, machine, 'PYCICLE_GITHUB_BASE_BRANCH')
    if args.cdash_server:
        cdash_server = args.cdash_server
    else:
        cdash_server    = pyc_p.get_setting_for_project(args.project, machine, 'PYCICLE_CDASH_SERVER_NAME')
    cdash_project_name  = pyc_p.get_setting_for_project(args.project, machine, 'PYCICLE_CDASH_PROJECT_NAME')
    cdash_http_path     = pyc_p.get_setting_for_project(args.project, machine, 'PYCICLE_CDASH_HTTP_PATH')
    builds_per_pr_str   = pyc_p.get_setting_for_machine_project(args.project, machine, 'PYCICLE_BUILDS_PER_PR')
    builds_per_pr       = int(builds_per_pr_str)

    pyc_p.debug_print('-' * 30)
    print('PYCICLE_GITHUB_PROJECT_NAME  =', github_reponame)
    print('PYCICLE_GITHUB_ORGANISATION  =', github_organisation)
    print('PYCICLE_GITHUB_BASE_BRANCH   =', github_base)
    print('PYCICLE_CDASH_PROJECT_NAME   =', cdash_project_name)
    print('PYCICLE_CDASH_SERVER_NAME    =', cdash_server)
    print('PYCICLE_CDASH_HTTP_PATH      =', cdash_http_path)
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
    try:
        print('-' * 30)
        print("Connecting    :", "github.Github({},{})".format(github_organisation, args.user_token))
        git  = github.Github(github_organisation, args.user_token)
        print("Github User   :",git.get_user().name)
        print("Github Repo   :",github_reponame)
        try:
            org = git.get_organization(github_organisation)
            print("Organisation  :", org.login, org.name)
            repo = org.get_repo(github_reponame)
        except github.UnknownObjectException as ukoe:
            print("Exception     : Trying to recover from organization passed as name")
            git  = github.Github(args.user_token)
            repo = git.get_repo(github_reponame)
            print(vars(repo))
        except Exception as ex:
            print("unexpected exception caught in github connect:",ex)
        print("Repo Fullname :", repo.full_name)
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
    github_t1       = datetime.datetime.now()
    scrape_t1       = github_t1 + datetime.timedelta(hours=-1)
    scrape_tdiff    = 0
    force           = args.force
    #
    while True:
        #
        try:
            github_t2     = datetime.datetime.now()
            github_tdiff  = github_t2 - github_t1
            github_t1     = github_t2
            print('-' * 30)
            print('Checking github:', 'Time since last check:', github_tdiff.seconds, '(s)')
            print('-' * 30)

            base_branch = repo.get_branch(github_base) #should be PYCICLE_BASE
            base_sha    = base_branch.commit.sha
            pyc_p.debug_print(base_branch)
            #
            # just get a single PR if that was all that was asked for
            if args.pull_request!=0:
                pyc_p.debug_print('Getting PR', args.pull_request)
                try:
                    pr = repo.get_pull(args.pull_request)
                except Exception as ex:
                    pyc_p.debug_print('Could not get PR - is it valid?:', ex)
                    break
                pyc_p.debug_print(pr)
                pull_requests = [pr]
                pyc_p.debug_print('Requested PR: ', pr)
            # otherwise get all open PRs
            else:
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
                pr_list[branch_id] = [machine, branch_name, pr.get_commits().reversed[0]]
                #
                if args.pull_request!=0 and pr.number!=args.pull_request:
                    continue
                if not pr.mergeable:
                    pyc_p.debug_print('Skipping PR - not mergeable')
                    continue
                #
                if not args.scrape_only:
                    update = force or needs_update(args.project, branch_id, branch_name, branch_sha, base_sha)
                    if update:
                        choose_and_launch(args.project, machine, branch_id, short_name, args.cmake_options, builds_per_pr)

            # also build the base branch if it has changed
            if not args.scrape_only and args.pull_request==0:
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
                for branch_id in builds_done:
                    if branch_id in pr_list:
                        # machine, scrape_file, branch_id, branch_name, head_commit
                        scrape_testing_results(
                            args.project,
                            pr_list[branch_id][0], builds_done.get(branch_id),
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
