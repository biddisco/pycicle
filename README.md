# pycicle
Python Continuous Integration Command Line Engine

A simple command line tool to poll github for Pull Requests on a project and trigger builds when they change,
or when the master branch changes. Projects are assumed to be `C++`, use `CMake` for configuration and `CTest`
for testing with results submitted to a `CDash` dasboard.

The project was/is created for use with [HPX](https://github.com/STEllAR-GROUP/hpx)
and the HPX (CDash) dashboard associated with the project is [Here](http://cdash.cscs.ch/index.php?project=HPX)

## What does it do and how does it work
When running, pycicle will poll github once every N seconds and look for open pull requests using the pygithub API.
A list of open PRs is generated, and for each that is mergeable, pycicle looks at the latest SHA on the PR
and the latest SHA on master branch, and if either has changed since last time it looked,
it marks that PR as needing an update (rebuild).

A build is triggered by ssh-ing into a remote machine and calling `ctest -S dashboard-script.cmake <args>`
to spawn a build, or by calling `ctest -S dashboard-slurm.cmake <args>` if the machine is using slurm job control.
The slurm version of the script does nothing more than wrap the call to the dashboard script
inside an `SBATCH` wrapper so that the build is triggered by slurm on a compute node, rather than on the login node.

The build script will checkout the latest master branch, merge the PR (branch) into it,
then do ctest configure/build/test with submit steps after each configure/build/test step respectively
to produce an entry in the dashboard that is updated as the build progresses.
Note that if a pull request is modified whilst a previous build is still going, an `scancel`
of the existing job is used to terminate the first before starting the second.

Every M seconds, pycicle will find (scrape) a small log file generated in each build dir that contains a summary
of config/build/test results and update the github PR status based on it so that build failures
flag the PR as not ready for merging.

## Why use this instead of Jenkins/other CI tool
Running pycicle is very simple, and can be done by a user, manually or in a cron job, and uses the
same permissions as the user starting it. When a build fails, the user can `ssh` into the machine, `cd` into
the build dir, manually (re)start the build, see the errors, `cd` into the source dir and inspect the repo/branch that
is being tested and tweak anything necessary to get it working - even fix the build/test errors and update the PR
from the test build's copy of the repo.
You can run it inside a screen session, at startup or just leave a terminal open with it and start and stop it
on demand.

CDash supports the display of build information from many sites, so pycicle can be run at several instituations
with results from machines at each being submitted to a single CDash dashboard.
Machines at each location may be configured by users and no central coordination is required -
it is this aspect that makes it attractive to projects like HPX that have developers in several
locations and compute resources ditributed worldwide with different architectures/hardware.

## Running pycicle
```bash
python ./pycicle.py -m daint
```

## options
```
usage: pycicle.py [-h] [-s] [--no-slurm] [-d] [-r PYCICLE_ROOT] [-t USER_TOKEN]
                  [-m MACHINES [MACHINES ...]] [-p PULL_REQUEST] [-c]
```

`-s, --slurm           : Use slurm for job launching (default).`
When slurm is enabled, builds are triggered by launching a slurm script that in turn launches the ctest build script

`--no-slurm            : Disable slurm job launching`
When disabled, the script is executed directly, you might want to do this when setting up a build script
and using a login node for test purposes.

`-d, --debug           : Enable debug mode`
When using debug mode, remote commands are echoed to the screen instead of being executed. This is useful
when setting up your first build and trying to get commands right or debugging pycicle itself.

`-r PYCICLE_ROOT, --pycicle-root : pycicle root path/directory`
The environment variable $PYCICLE_ROOT should be set on the machine you are running pycicle on,
and also on the machine where builds are being triggered - but when supplied on the command line,
it overrides the environment variable for the local machine (not the remote one, but we could add that).
It is the root of the build/src tree where pycicle will write all its files.

`-t PYCICLE_GITHUB_TOKEN, --github-token PYCICLE_GITHUB_TOKEN : github token used to authenticate access`
To access github (and set status of PRs) you need to generate a developer token on the github website and use it
when initializing the pygithub object. Set the environment variable $PYCICLE_GITHUB_TOKEN or pass it on the
command line.
Make sure you give yourself write permission if you want to set the status of PRs using pycicle.

`-m MACHINES [MACHINES ...], --machines MACHINES [MACHINES ...] list of machines to use for testing`
Currently pycicle only supports a single machine at a time, but the plan is to allow spawning build on several
machines from a single pycicle instance. Currently we run one instance on a login node of each machine or run
one on a local terminal and use `ssh` to spawn on a single remote machine.

`-p PULL_REQUEST, --pull-request PULL_REQUEST : A single PR number for limited testing`
When debugging pycicle, or your build scripts, to avoid spamming github, use a known PR numbe to tell pycicle
to ignore all other PRs apart from that one.

`-c, --scrape-only     : Only scrape results and set github status (no building)`
When this is set, pycicle will not trigger any builds, it will only look for completed build logs on the remote
machine and scrape them for the status it needs to set github PRs to enabled or disabled.

## Installing/setting up
Create a pycicle directory on a machine, set $PYCICLE_ROOT to the path and add it
to your `bash` startup so that a machine that ssh's in will have it set.

### Running pycicle and doing build/tests on the same machine
```
# setup for machine that will do builds and run pycicle script
PYCICLE_ROOT=/user/biddisco/pycicle
mkdir -p $PYCICLE_ROOT
cd $PYCICLE_ROOT
# clone pycicle into the root
git clone https://github.com/biddisco/pycicle.git pycicle
# make a copy of your project git repository here as well
cp -r /path/to/your/project/hpx $PYCICLE_ROOT/repo
# alternatively, cloe your project into a dir called repo
# git clone git@github.com:STEllAR-GROUP/hpx.git repo
```

### Running pycicle on machine A, build/test on machine B
Follow the steps above on the machine that will do builds.
On the machine that will run the scripts and trigger builds (on the remote machine)
```
# setup for machine that runs the pycicle script only
PYCICLE_ROOT=/user/biddisco/pycicle
mkdir -p $PYCICLE_ROOT
cd $PYCICLE_ROOT
# clone pycicle into the root
git clone https://github.com/biddisco/pycicle.git pycicle
```

Note - your project is copied/cloned into a directory called `repo`.
This is because some of scripts use the path `$PYCICLE_ROOT/repo` for the initial
source code reference. This should be fixed to use the real project name.

Why do we keep a copy of the project repository in the pycicle root dir?
The reason is that when initially developing pycicle on a laptop, using wifi internet access,
it turned out to be very painful to git clone the entire HPX project for each PR being tested,
and so pycicle will copy the repo from it's own private copy for each PR
rather than cloning - this is much faster when the repo is many GBs.
Note that each branch being tested will still be pulled from the origin (github),
but this is much faster than a full clone.
(NB. Doing a shallow clone isn't a great solution because you need to go back far enough
to ensure the merge-base between the PR and the master branch is in the history).

after using the above setup, pycicle can be started using a command like
```
python $PYCICLE_ROOT/pycicle/pycicle.py -m greina
```
When it runs, two directories will be created
```
$PYCICLE_ROOT/src
$PYCICLE_ROOT/build
```
and these will be populated with source trees and build trees for PRs and the master branch
when they need to be built.

## Inspect
The HPX project runs a tool called `inspect` on the code (similar to clang-format/style checks etc) to ensure
that `#includes` are set correctly and basic format checks pass.
Currently this is hardcoded into the ctest script as a prebuild step to do
an extra configure and submit step to a different dashboard track. This needs to be cleaned up a bit to make
pycicle portable to other projects.

## Docs
Not yet implemented, but adding a doc build step to `pycicle.py` or the ctest scripts should be straightforward.

# Config
The config directory contains examples of two slurm operated machines {greina/daint}, these can be
copied/modified to create new configurations for other machines.
The machine name passed on the commandline `python pycicle.py -m daint` (in this example `daint`)
must correspond to the name of a cmake configuratiuon file for the machine in the config
directory.

Details of the CMake Vars that need to be set will follow. Most is self explanatory for developers
familiar with CMake/CTest.

## Force rebuilds
In the $PYCICLE_ROOT directory of the machine that runs the pycicle script you can delete
the file that holds the last checked SHA from github. This will trigger a new build for
all PRs.
```
cd $PYCICLE_ROOT
find src -maxdepth 2 -name last_pr_sha.txt -delete
```
If you only want to force a rebuild for PR 3042, then
```
cd $PYCICLE_ROOT
rm -f src/3042/last_pr_sha.txt
```
NB. A command line param should be added to allow this to be done without manual deletion.

## ToDo
Currently, scripts are configured to work with the HPX project and some things have been hardcoded,
these need to be changed to easily editable config settings.

I don't really know anything about python, so have no real idea if this works with python2
and python3. I think it does and I added a few imports to make it work, but it isn't tested.

