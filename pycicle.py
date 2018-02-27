#  Copyright (c) 2017 John Biddiscombe
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
from __future__ import absolute_import, division, print_function #unicode_literals
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

#--------------------------------------------------------------------------
# Command line args
#--------------------------------------------------------------------------
parser = argparse.ArgumentParser()

#----------------------------------------------
# project name
#----------------------------------------------
project = ''
parser.add_argument('-P', '--project', dest='project',
    help='Project name (case sensitive) used as root of config dir for settings')

#----------------------------------------------
# enable or disable slurm for Job launching
# prefer this to be like the pbs option, just building local
# is more sensible default  
#----------------------------------------------
parser.add_argument('-s', '--slurm', dest='slurm', action='store_true',
    help="Use slurm for job launching (default)")
parser.add_argument('--no-slurm', dest='slurm', action='store_false',
    help="Disable slurm job launching")
parser.set_defaults(slurm=True)

#----------------------------------------------
# enable pbs for Job launching
#----------------------------------------------
parser.add_argument('--pbs', dest='pbs', action='store_true',
    help="Use pbs for job launching")
parser.set_defaults(pbs="False")


#----------------------------------------------
# enable/debug mode
#----------------------------------------------
parser.add_argument('-d', '--debug', dest='debug', action='store_true',
    default=False, help="Enable debug mode")

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
    default=pycicle_dir, help='pycicle root path/directory')

#--------------------------------------------------------------------------
# github token used to authenticate access
#--------------------------------------------------------------------------
user_token = 'generate a token and paste it here, or set env var'
user_token = os.environ.get('PYCICLE_GITHUB_TOKEN', user_token)
parser.add_argument('-t', '--github-token', dest='user_token', type=unicode,
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
# CMake Build Type
#--------------------------------------------------------------------------
parser.add_argument('-b', '--build-type', dest='build_type',
                    help='Cmake Build Type', default="Release")

#----------------------------------------------
# print summary of parse args
#----------------------------------------------
args = parser.parse_args()
print('pycicle: project     :', args.project)
print('pycicle: slurm       :', 'enabled' if args.slurm else 'disabled')
print('pycicle: pbs       :', 'enabled' if args.pbs else 'disabled')
print('pycicle: debug       :',
    'enabled (no build trigger commands will be sent)' if args.debug else 'disabled')
print('pycicle: scrape-only :', 'enabled' if args.slurm else 'disabled')
print('pycicle: force       :', 'enabled' if args.force else 'disabled')
print('pycicle: path        :', args.pycicle_dir)
print('pycicle: token       :', args.user_token)
print('pycicle: machines    :', args.machines)
print('pycicle: PR          :', args.pull_request)
print('pycicle: build_type  :', args.build_type)
#
machine = args.machines[0]
build_type = args.build_type
print('\ncurrent implementation supports only 1 machine :', machine, '\n')

#--------------------------------------------------------------------------
# read one value from the CMake config for use elsewhere
#--------------------------------------------------------------------------
def get_setting_for_machine(project, machine, setting) :
    current_path = os.path.dirname(os.path.realpath(__file__))
#    print('looking for setting', setting, ' in file', current_path + '/config/' + project + '/' + machine + '.cmake')
    f = open(current_path + '/config/' + project + '/' + machine + '.cmake')
    for line in f:
        m = re.findall(setting + ' *\"(.+?)\"', line)
        if m:
            return m[0]
    return ''

#--------------------------------------------------------------------------
# launch a command that will start one build
#--------------------------------------------------------------------------
def launch_build(nickname, compiler, branch_id, branch_name) :
    # consider import paramiko
    # client = paramiko.SSHClient()
    # client.load_system_host_keys()
    # client.connect(remote_ssh)
     
    remote_ssh  = get_setting_for_machine(args.project, nickname, 'PYCICLE_MACHINE')
    remote_path = get_setting_for_machine(args.project, nickname, 'PYCICLE_ROOT')
    remote_http = get_setting_for_machine(args.project, nickname, 'PYCICLE_HTTP')
    print ("launching build", compiler, branch_id, branch_name)
    # we are not yet using these as 'options'
    boost = 'x.xx.x'
    
    # This is a clumsy way to do this.
    if args.slurm:
        script = 'dashboard_slurm.cmake'
    elif args.pbs:
        print ("calling pbs build:", args.project)
        script = 'dashboard_pbs.cmake'
    else:
        script = 'dashboard_script.cmake'

    if 'local' not in remote_ssh:
       # We need to setup the environment on the remote machine, often even cmake comes from
        # a module or the like.
        org_dir = '.'
        cmd1 = ['. /software/user_tools/current/cades-cnms/spack/share/spack/setup-env.sh;',
                'spack load cmake;',
                'ctest']

        cmd1 = ' '.join(cmd1)
        #if not args.debug else {'echo ', ' ', 'ctest'}

        cmd = ['ssh', remote_ssh, cmd1, '-S',
               remote_path                      + '/pycicle/' + script ]
    else:
        # if we're local we assume the current context has the module setup
        #org_dir = os.getcwd()
        #os.chdir(remote_path + '/pycicle/')
        print ( os.getcwd())
        cmd = ['ctest','-S', "./pycicle/" + script ] #'./pycicle/'

    cmd = cmd + [ '-DPYCICLE_ROOT='                + remote_path,
                  '-DPYCICLE_HOST='                + nickname,
                  '-DPYCICLE_PROJECT_NAME='        + args.project,
                  '-DPYCICLE_GITHUB_PROJECT_NAME=' + github_reponame,
                  '-DPYCICLE_GITHUB_ORGANISATION=' + github_organisation,
                  '-DPYCICLE_PR='                  + branch_id,
                  '-DPYCICLE_BRANCH='              + branch_name,
                  '-DPYCICLE_RANDOM='              + random_string(10),
                  '-DPYCICLE_COMPILER='            + compiler,
                  '-DPYCICLE_BOOST='               + boost,
                  '-DPYCICLE_BUILD_TYPE='          + args.build_type,
                  '-DPYCICLE_MASTER='              + github_master,
                  # These are to quiet warnings from ctest about unset vars
                  '-DCTEST_SOURCE_DIRECTORY=.',
                  '-DCTEST_BINARY_DIRECTORY=.',
                  '-DCTEST_COMMAND=":"' ]
    if args.debug:
        print('\n' + '-' * 20, 'Debug\n', subprocess.list2cmdline(cmd))
        p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        print('-' * 20 + '\n')
        debug_out, _ = p.communicate()
        print (debug_out)
    else:
        print('\n' + '-' * 20, 'Executing\n', subprocess.list2cmdline(cmd))
        p = subprocess.Popen(cmd)
        print('-' * 20 + '\n')

    # os.chdir(org_dir)
    return None

#--------------------------------------------------------------------------
# launch one build from a list of options
#--------------------------------------------------------------------------
def choose_and_launch(project, machine, branch_id, branch_name) :
    print ("choose", project, machine, branch_id, branch_name)
    if project=='hpx' and machine=='daint':
        if bool(random.getrandbits(1)):
            launch_build(machine, 'gcc', branch_id, branch_name)
        else:
            launch_build(machine, 'clang', branch_id, branch_name)
    else:
        launch_build(machine, 'gcc', branch_id, branch_name)

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
        print ('File removed', file)
    except Exception as ex:
        print ('File deletion failed', ex)

#--------------------------------------------------------------------------
# find all the PR build jobs submitted and from them the build dirs
# that we can use to scrape results from
#--------------------------------------------------------------------------
def find_scrape_files(project, nickname) :
    remote_ssh  = get_setting_for_machine(project, nickname, 'PYCICLE_MACHINE')
    remote_path = get_setting_for_machine(project, nickname, 'PYCICLE_ROOT')

    JobFiles   = []
    PR_numbers = {}
    #
    try:
        if 'local' not in remote_ssh:
            cmd = ['ssh', remote_ssh ] 
        else:
            cmd = []

        cmd = cmd + [ 'find ', '-path \'',
                       remote_path + '/build/'+project+'-*\'',
                      '-maxdepth 2',
                      '-name pycicle-TAG.txt']
        result = subprocess.check_output(cmd).splitlines()
        # print('find pycicle-TAG using', cmd, ' gives :', result)
        for s in result: JobFiles.append(s.decode('utf-8'))

        # for each build dir, return the PR number and results file
        for f in JobFiles:
            m = re.search(r'/build/'+project+'-(.+?)-.*/pycicle-TAG.txt', f)
            print('search pycicle-TAG gives :', m)
            if m:
                PR_numbers[m.group(1)] = f

    except Exception as ex:
        print ("find_scrap_files failed", cmd, ex)
    return PR_numbers

#--------------------------------------------------------------------------
# collect test results so that we can update github PR status
#--------------------------------------------------------------------------
def scrape_testing_results(project, nickname, scrape_file, branch_id, branch_name, head_commit) :
    remote_ssh  = get_setting_for_machine(project, nickname, 'PYCICLE_MACHINE')

    if 'local' not in remote_ssh:
        cmd = ['ssh', remote_ssh ]
    else:
        cmd = []
    cmd = cmd + [ 'cat', scrape_file ]

    Config_Errors = 0
    Build_Errors  = 0
    Test_Errors   = 0
    Errors        = []

    context = re.search(r'/build/'+project+'.*?-(.+)/pycicle-TAG.txt', scrape_file)
    print('context pycicle-TAG', context)
    if context:
        origin = nickname + '-' + context.group(1)
    else:
        origin = 'unknown'

    try:
        result = subprocess.check_output(cmd).split()
        for s in result: Errors.append(s.decode('utf-8'))
        print('Errors are', Errors)

        Config_Errors = int(Errors[0])
        Build_Errors  = int(Errors[1])
        Test_Errors   = int(Errors[2])
        StatusValid   = True if len(Errors)>3 else False
        if StatusValid:
            DateStamp = Errors[3]
            DateURL   = DateStamp[0:4]+'-'+DateStamp[4:6]+'-'+DateStamp[6:8]
            print('Extracted date as', DateURL)

            URL = ('http://cdash.cscs.ch/index.php?project=' + cdash_servername +
                   '&date=' + DateURL +
                   '&filtercount=1' +
                   '&field1=buildname/string&compare1=63&value1=' +
                   branch_id + '-' + branch_name)

            if args.debug:
                print ('Debug github PR status', URL)
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
                print ('Done setting github PR status for', origin)

        erase_file(remote_ssh, scrape_file)

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
def needs_update(project_name, branch_id, branch_name, branch_sha, master_sha):
    directory     = pycicle_dir + '/src/' + project_name + '-' + branch_id
    status_file   = directory + '/last_pr_sha.txt'
    update        = False
    #
    if not os.path.exists(directory):
        os.makedirs(directory)
        update = True
    else:
        try:
            f = open(status_file,'r')
            lines = f.readlines()
            if lines[0].strip() != branch_sha:
                print(branch_id, branch_name, 'changed : trigger update')
                update = True
            elif (lines[1].strip() != master_sha):
                print('master changed : trigger update')
                update = True
            f.close()
        except:
            print(branch_id, branch_name, 'status error : trigger update')
            update = True
    #
    if update:
        f = open(status_file,'w')
        f.write(branch_sha + '\n')
        f.write(master_sha + '\n')
        f.close()
    #
    return update

#--------------------------------------------------------------------------
# Delete old build and src dirs from pycicle root
#--------------------------------------------------------------------------
def delete_old_files(nickname, path, days) :
    remote_ssh  = get_setting_for_machine(args.project, nickname, 'PYCICLE_MACHINE')
    directory   = '${PYCICLE_ROOT}/'+ path
    Dirs        = []

    if 'local' not in remote_ssh:
        cmd_transport = ['ssh', remote_ssh ]
    else:
        cmd_transport = []
    cmd = cmd_transport + ['find ', directory,
                 ' -mindepth 1 -maxdepth 1 -type d -mtime +' + str(days)]

    try:
        result = subprocess.check_output(cmd).split()
        for s in result:
            temp = s.decode('utf-8')
            cmd = cmd_transport + [ 'rm', '-rf', temp]
            print('Deleting old/stale directory : ', cmd)
            result = subprocess.check_output(cmd).split()
    except Exception as ex:
        print('Cleanup failed for ', nickname, ex)

#--------------------------------------------------------------------------
# main program starts here
#
# Create a Github instance:
#--------------------------------------------------------------------------
github_reponame     = get_setting_for_machine(args.project, args.project, 'PYCICLE_GITHUB_PROJECT_NAME')
github_organisation = get_setting_for_machine(args.project, args.project, 'PYCICLE_GITHUB_ORGANISATION')
github_master       = get_setting_for_machine(args.project, args.project, 'PYCICLE_GITHUB_MASTER_BRANCH')
cdash_servername    = get_setting_for_machine(args.project, args.project, 'PYCICLE_CDASH_SERVER_NAME')

print('PYCICLE_GITHUB_PROJECT_NAME  is', github_reponame)
print('PYCICLE_GITHUB_ORGANISATION  is', github_organisation)
print('PYCICLE_GITHUB_MASTER_BRANCH is', github_master)
print('PYCICLE_CDASH_SERVER_NAME    is', cdash_servername)

poll_time   = 60
scrape_time = 10*60

print (user_token)
try:
    #git  = github.Github(github_organisation, user_token)
    git = github.Github(user_token.encode('UTF-8')) #user_token)
    print (git.get_user())
    org  = git.get_organization('eth-cscs') # github_organisation)
    print (org)
    repo = org.get_repo(github_reponame)
except Exception as e:
    print(e, 'Failed to connect to github. Network down?')

#--------------------------------------------------------------------------
# Scrape-list : machine/build that we must check for status files
# This will need to support lots of build/machine combinations eventually
#--------------------------------------------------------------------------
scrape_list = {"cadesCondo":"Debug"}

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
        print('Checking github:', 'Time since last check', github_tdiff.seconds, '(s)')
        #
        master_branch = repo.get_branch(repo.default_branch)
        master_sha    = master_branch.commit.sha
        #
        pull_requests = repo.get_pulls('open')
        pr_list       = {}
        for pr in pull_requests:
            #
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
                update = force or needs_update(args.project, branch_id, branch_name, branch_sha, master_sha)
                if update:
                    choose_and_launch(args.project, machine, branch_id, branch_name)

        # also build the master branch if it has changed
        if not args.scrape_only and args.pull_request==0:
            if force or needs_update(args.project, 'master', 'master', master_sha, master_sha):
                choose_and_launch(args.project, machine, 'master', 'master')
                pr_list['master'] = [machine, 'master', master_branch.commit, ""]

        scrape_t2    = datetime.datetime.now()
        scrape_tdiff = scrape_t2 - scrape_t1
        if (scrape_tdiff.seconds > scrape_time):
            scrape_t1 = scrape_t2
            print('Scraping results:', 'Time since last check', scrape_tdiff.seconds, '(s)')
            builds_done = find_scrape_files(args.project, machine)
            print(builds_done)
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
                        get_setting_for_machine(args.project, machine, 'PYCICLE_MACHINE'),
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
