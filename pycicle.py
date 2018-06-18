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
import re
import string
import random
import socket
import datetime
import argparse
from random import randint
from pprint import pprint

from pycicle_params import PycicleParams

def get_command_line_args():
    #--------------------------------------------------------------------------
    # Command line args
    #--------------------------------------------------------------------------
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
    # CMake build type
    #--------------------------------------------------------------------------
    parser.add_argument('-b', '--build-type', dest='build_type',
                        default='Release', help='CMake build type used for all builds')

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
    # CDash Server
    #--------------------------------------------------------------------------
    parser.add_argument('--cdash-server', dest='cdash_server',
                        help='CDash server', default=None)

    #----------------------------------------------
    # print summary of parse args
    #----------------------------------------------
    args = parser.parse_args()
    machine = args.machines[0]
    build_type = args.build_type
    print('-' * 30)
    print('pycicle: project     :', args.project)
    print('pycicle: debug       :',
          'enabled (no build trigger commands will be sent)' if args.debug else 'disabled')
    print('pycicle: scrape-only :', 'enabled' if args.scrape_only else 'disabled')
    print('pycicle: force       :', 'enabled' if args.force else 'disabled')
    print('pycicle: path        :', args.pycicle_dir)
    print('pycicle: token       :', args.user_token)
    print('pycicle: machines    :', args.machines)
    print('pycicle: PR          :', args.pull_request)
    print('pycicle: build_type  :', args.build_type)
    print('pycicle: machine     :', machine, '(only 1 supported currently)')
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
# Pick one option at random from a list of options
#--------------------------------------------------------------------------
def generate_random_simple_options(option):
    cmake_option = {}
    key = option[0]
    values = option[1]
    randval = randint(0, len(values)-1)
    cmake_option[key] = values[randval]
    return cmake_option

#--------------------------------------------------------------------------
# find all the simple options that are defined for the project
# the return from this is a MAP of options,
# key = option name, value = list of choices
#--------------------------------------------------------------------------
def get_simple_options(project, machine, setting) :
    current_path = os.path.dirname(os.path.realpath(__file__))
    f = open(current_path + '/config/' + project + '/' + machine + '.cmake')

    regex = setting + '*\((.+?)\)'
    options = {}
    for line in f:
        m = re.findall(regex, line)
        if m:
            p = re.findall('([^ ]+) +(.+)', m[0])
            if p:
                pyc_p.debug_print('Option found', p[0][0],  '(values)', p[0][1])
            options[p[0][0]] = p[0][1].split()
    return options

#--------------------------------------------------------------------------
# Find options that depend on another simple option
# Given a simple option, find all the other options that can be enabled
# or set when the simple option has a certain value
# returns a map values that each contains a list of lists of new options
# so if simple_option is ON, then dependent_option_1 can be a,b,c
# if simple_option is OFF, then dependent_option_1_or_2 can be d,e,f
#
# Map key         Value(list)  map of options     list of values
# simple_option -> value_1 -> dependent_option_1 -> value_a,b,c
#                          -> dependent_option_2 -> value_d,e,f
#               -> value_2 -> dependent_option_3 -> value x,y,z
#--------------------------------------------------------------------------
def get_dependent_options(project, machine, setting, dependency, dep_value) :
    current_path = os.path.dirname(os.path.realpath(__file__))
    f = open(current_path + '/config/' + project + '/' + machine + '.cmake')
    # "dependency" "value" "new_option" "new_option_values"
    regex = setting + '*\(' + dependency + ' +([^ ]+) +' + '(.+?)\)'
    #
    cmake_options = {}
    for line in f:
        m = re.findall(regex, line)
        if m:
            value = m[0][0]
            new_option_and_values   = m[0][1].split()
            new_option_and_values_l = [new_option_and_values[0], new_option_and_values[1:]]
            # don't set a dependent value if parent option doesn't match
            if value!=dep_value:
                continue
            dependent_option        = generate_random_simple_options(new_option_and_values_l)
            pyc_p.debug_print('depend option choice', dependent_option, 'from', new_option_and_values[1:])
            cmake_options.update(dependent_option)

    return cmake_options

#--------------------------------------------------------------------------
#
#--------------------------------------------------------------------------
def find_build_options(nickname) :
    cmake_options = {}
    options = get_simple_options(args.project, nickname, 'PYCICLE_CONFIG_OPTION')
    pyc_p.debug_print('simple options found', options)
    for option in options.items():
        pyc_p.debug_print('-'*30)
        key = option[0]
        choice = generate_random_simple_options(option)
        pyc_p.debug_print('simple option choice', choice, 'from', option[1])
        cmake_options.update(choice)
        cmake_options.update(get_dependent_options(args.project, nickname, 'PYCICLE_DEPENDENT_OPTION', key, cmake_options[key]))
    pyc_p.debug_print('-'*30)
    pyc_p.debug_print('Random cmake settings :', cmake_options)
    cmake_string = ''
    for i in cmake_options.items():
        cmake_string += '-D' + i[0] + '=' + i[1] + ' '
    pyc_p.debug_print('CMake string', cmake_string)
    pyc_p.debug_print('-'*30)
    return cmake_string

#--------------------------------------------------------------------------
# launch a command that will start one build
#--------------------------------------------------------------------------
def launch_build(nickname, compiler_type, branch_id, branch_name, cmake_options) :
    remote_ssh  = pyc_p.get_setting_for_machine(args.project, nickname, 'PYCICLE_MACHINE')
    remote_path = pyc_p.get_setting_for_machine(args.project, nickname, 'PYCICLE_ROOT')
    remote_http = pyc_p.get_setting_for_machine(args.project, nickname, 'PYCICLE_HTTP')
    job_type    = pyc_p.get_setting_for_machine(args.project, nickname, 'PYCICLE_JOB_LAUNCH')
    pyc_p.debug_print('launching build', compiler_type, branch_id, branch_name, job_type, cmake_options)
    # we are not yet using these as 'options'
    boost = 'x.xx.x'

    # This is a clumsy way to do this.
    # implies local default, should be explicit somewhere
    if job_type=='slurm':
        pyc_p.debug_print("slurm build:", args.project)
        script = 'dashboard_slurm.cmake'
    elif job_type=='pbs':
        pyc_p.debug_print("pbs build:", args.project)
        script = 'dashboard_pbs.cmake'
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
    else:
        # if we're local we assume the current context has the module setup
        pyc_p.debug_print("Local build working in:", os.getcwd())
        cmd = ['ctest','-S', script ] #'./pycicle/'

    build_type = pyc_p.get_setting_for_machine(args.project, nickname, 'PYCICLE_BUILD_TYPE')

    cmd = cmd + [ '-DPYCICLE_ROOT='                + remote_path,
                  '-DPYCICLE_HOST='                + nickname,
                  '-DPYCICLE_PROJECT_NAME='        + args.project,
                  '-DPYCICLE_GITHUB_PROJECT_NAME=' + github_reponame,
                  '-DPYCICLE_GITHUB_ORGANISATION=' + github_organisation,
                  '-DPYCICLE_PR='                  + branch_id,
                  '-DPYCICLE_BRANCH='              + branch_name,
                  '-DPYCICLE_RANDOM='              + random_string(10),
                  '-DPYCICLE_COMPILER_TYPE='       + compiler_type,
                  '-DPYCICLE_BOOST='               + boost,
                  '-DPYCICLE_BUILD_TYPE='          + build_type,
                  '-DPYCICLE_BASE='                + github_base,
                  '-DPYCICLE_CMAKE_OPTIONS='        + cmake_options,
                  # These are to quiet warnings from ctest about unset vars
                  '-DCTEST_SOURCE_DIRECTORY=.',
                  '-DCTEST_BINARY_DIRECTORY=.',
                  '-DCTEST_COMMAND=":"' ]
    if args.debug:
        print('\n' + '-' * 20, 'Debug\n', subprocess.list2cmdline(cmd))
        p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        print('-' * 20 + '\n')
        debug_out, _ = p.communicate()
        print(debug_out)
    else:
        print('\n' + '-' * 20, 'Executing\n', subprocess.list2cmdline(cmd), '\n')
        # if local then wait for the result
        if 'local' in remote_ssh:
            try:
                result = subprocess.check_output(cmd).splitlines()
                print('-' * 30)
                print(result)
            except Exception as ex:
                print("Caught exception from subprocess.checkout:")
                print(ex)
        else:
            p = subprocess.Popen(cmd)
        print('-' * 20 + '\n')

    # os.chdir(org_dir)
    return None

#--------------------------------------------------------------------------
# launch one build from a list of options
#--------------------------------------------------------------------------
def choose_and_launch(project, machine, branch_id, branch_name, compiler_type, cmake_options) :
    pyc_p.debug_print("Begin : choose_and_launch", project, machine, branch_id, branch_name, cmake_options)
    if project=='hpx' and machine=='daint':
        if bool(random.getrandbits(1)):
            compiler_type = 'gcc'
        else:
            compiler_type = 'clang'
    launch_build(machine, compiler_type, branch_id, branch_name, cmake_options)

#--------------------------------------------------------------------------
# Utility function to remove a file from a remote filesystem
#--------------------------------------------------------------------------
def erase_file(remote_ssh, file):
    # erase the pycicle scrape file if we have set status corectly
    try:
        if 'local' not in remote_ssh:
            cmd = ['ssh', remote_ssh ]
        else:
            cmd = []
        cmd = cmd + [ 'rm', '-f', file]
        result = subprocess.check_output(cmd).split()
        print('File removed', file)
    except Exception as ex:
        print('File deletion failed', ex)

#--------------------------------------------------------------------------
# find all the PR build jobs submitted and from them the build dirs
# that we can use to scrape results from
#--------------------------------------------------------------------------
def find_scrape_files(project, nickname) :
    remote_ssh  = pyc_p.get_setting_for_machine(project, nickname, 'PYCICLE_MACHINE')
    remote_path = pyc_p.get_setting_for_machine(project, nickname, 'PYCICLE_ROOT')

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
def scrape_testing_results(project, nickname, scrape_file, branch_id, branch_name, head_commit) :
    remote_ssh  = pyc_p.get_setting_for_machine(project, nickname, 'PYCICLE_MACHINE')

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
        origin = nickname + '-' + context.group(1)
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
def delete_old_files(nickname, path, days) :
    remote_ssh  = pyc_p.get_setting_for_machine(args.project, nickname, 'PYCICLE_MACHINE')
    remote_path = pyc_p.get_setting_for_machine(args.project, nickname, 'PYCICLE_ROOT')
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
        print('Cleanup failed for ', nickname, ex)


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
    build_type = args.build_type

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
    github_reponame     = pyc_p.get_setting_for_machine(args.project, args.project, 'PYCICLE_GITHUB_PROJECT_NAME')
    github_organisation = pyc_p.get_setting_for_machine(args.project, args.project, 'PYCICLE_GITHUB_ORGANISATION')
    github_base         = pyc_p.get_setting_for_machine(args.project, args.project, 'PYCICLE_GITHUB_BASE_BRANCH')
    if args.cdash_server:
        cdash_server = args.cdash_server
    else:
        cdash_server    = pyc_p.get_setting_for_machine(args.project, args.project, 'PYCICLE_CDASH_SERVER_NAME')
    cdash_project_name  = pyc_p.get_setting_for_machine(args.project, args.project, 'PYCICLE_CDASH_PROJECT_NAME')
    cdash_http_path     = pyc_p.get_setting_for_machine(args.project, args.project, 'PYCICLE_CDASH_HTTP_PATH')
    compiler_type       = pyc_p.get_setting_for_machine(args.project, args.machines[0], 'PYCICLE_COMPILER_TYPE')

    pyc_p.debug_print('-' * 30)
    print('PYCICLE_GITHUB_PROJECT_NAME  =', github_reponame)
    print('PYCICLE_GITHUB_ORGANISATION  =', github_organisation)
    print('PYCICLE_GITHUB_BASE_BRANCH   =', github_base)
    print('PYCICLE_COMPILER_TYPE        =', compiler_type)
    print('PYCICLE_CDASH_PROJECT_NAME   =', cdash_project_name)
    print('PYCICLE_CDASH_SERVER_NAME    =', cdash_server)
    print('PYCICLE_CDASH_HTTP_PATH      =', cdash_http_path)
    pyc_p.debug_print('-' * 30)

    #--------------------------------------------------------------------------
    # get options for build
    #--------------------------------------------------------------------------
    cmake_options_string = find_build_options(args.project)

    #--------------------------------------------------------------------------
    # @todo make these into options
    # 60 seconds between polls.
    poll_time   = 60
    # 10 mins between checks for results and cleanups.
    scrape_time = 10*60

    try:
        print("connecting to git hub with:")
        print("github.Github({},{})".format(github_organisation, args.user_token))
        git  = github.Github(github_organisation, args.user_token)
        print("Github User   :",git.get_user().name)
        print("Github Reponame:",github_reponame)
        try:
            org = git.get_organization(github_organisation)
            print("Organisation  :", org.login, org.name)
            repo = org.get_repo(github_reponame)
        except github.UnknownObjectException as ukoe:
            print("trying to recover from organization passed as name")
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
    pyc_p.debug_print("Before main polling routine github_base:",github_base)

    #--------------------------------------------------------------------------
    # main polling routine
    #--------------------------------------------------------------------------
    #
    github_t1       = datetime.datetime.now()
    scrape_t1       = github_t1 + datetime.timedelta(hours=-1)
    scrape_tdiff    = 0
    force           = args.force
    #
    random.seed(7)
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
                pr = repo.get_pull(args.pull_request)
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
                branch_sha  = pr.head.sha
                # need details, including last commit on PR for setting status
                pr_list[branch_id] = [machine, branch_name, pr.get_commits().reversed[0]]
                #
                if args.pull_request!=0 and pr.number!=args.pull_request:
                    continue
                if not pr.mergeable:
                    continue
                #
                if not args.scrape_only:
                    update = force or needs_update(args.project, branch_id, branch_name, branch_sha, base_sha)
                    if update:
                        choose_and_launch(args.project, machine, branch_id, branch_name, compiler_type, cmake_options_string)

            # also build the base branch if it has changed
            if not args.scrape_only and args.pull_request==0:
                if force or needs_update(args.project, github_base, github_base, base_sha, base_sha):
                    choose_and_launch(args.project, machine, github_base, github_base, compiler_type, cmake_options_string)
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
                        # nickname, scrape_file, branch_id, branch_name, head_commit
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
