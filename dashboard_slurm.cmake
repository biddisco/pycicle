#  Copyright (c) 2017-2018 John Biddiscombe
#
#  Distributed under the Boost Software License, Version 1.0. (See accompanying
#  file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)

cmake_minimum_required(VERSION 3.1 FATAL_ERROR)

#######################################################################
# For debugging this script
#######################################################################
message("Project name is  " ${PYCICLE_PROJECT_NAME})
message("Github name is   " ${PYCICLE_GITHUB_PROJECT_NAME})
message("Github org is    " ${PYCICLE_GITHUB_ORGANISATION})
message("Pull request is  " ${PYCICLE_PR})
message("PR-Branchname is " ${PYCICLE_BRANCH})
message("base branch is " ${PYCICLE_BASE})
message("Machine name is  " ${PYCICLE_HOST})
message("PYCICLE_ROOT is  " ${PYCICLE_ROOT})
message("Random string is " ${PYCICLE_RANDOM})
message("COMPILER is      " ${PYCICLE_COMPILER_TYPE})
message("BOOST is         " ${PYCICLE_BOOST})
message("Build type is    " ${PYCICLE_BUILD_TYPE})

#######################################################################
# Load machine specific settings
#######################################################################
include(${CMAKE_CURRENT_LIST_DIR}/config/${PYCICLE_PROJECT_NAME}/${PYCICLE_HOST}.cmake)

#######################################################################
# Generate a slurm job script and launch it
# we must pass all the parms we received through to the slurm script
#######################################################################
set(PYCICLE_JOB_SCRIPT_TEMPLATE ${PYCICLE_JOB_SCRIPT_TEMPLATE}
  "ctest "
  "-S ${PYCICLE_ROOT}/pycicle/dashboard_script.cmake "
  "-DPYCICLE_ROOT=${PYCICLE_ROOT} "
  "-DPYCICLE_HOST=${PYCICLE_HOST} "
  "-DPYCICLE_PROJECT_NAME=${PYCICLE_PROJECT_NAME} "
  "-DPYCICLE_GITHUB_PROJECT_NAME=${PYCICLE_GITHUB_PROJECT_NAME} "
  "-DPYCICLE_GITHUB_ORGANISATION=${PYCICLE_GITHUB_ORGANISATION} "
  "-DPYCICLE_PR=${PYCICLE_PR} "
  "-DPYCICLE_BRANCH=${PYCICLE_BRANCH} "
  "-DPYCICLE_COMPILER_TYPE=${PYCICLE_COMPILER_TYPE} "
  "-DPYCICLE_BOOST=${PYCICLE_BOOST} "
  "-DPYCICLE_BUILD_TYPE=${PYCICLE_BUILD_TYPE} "
  "-DPYCICLE_BASE=${PYCICLE_BASE} \n"
)

# write the job script into a temp file
file(WRITE "${PYCICLE_ROOT}/build/ctest-slurm-${PYCICLE_RANDOM}.sh" ${PYCICLE_JOB_SCRIPT_TEMPLATE})

#######################################################################
# Launch the dashboard test using slurm
# 1 Cancel any build using the same name as this one so that multiple
#   pushes to the same branch are handled cleanly
# 2 Spawn a new build
#######################################################################
message("sbatch \n"
    ${PYCICLE_ROOT}/build/ctest-slurm-${PYCICLE_RANDOM}.sh
)

execute_process(
  COMMAND bash "-c" "scancel $(squeue -n ${PYCICLE_PROJECT_NAME}-${PYCICLE_PR}-${PYCICLE_BUILD_STAMP} -h -o %A) > /dev/null 2>&1;
                     sbatch ${PYCICLE_ROOT}/build/ctest-slurm-${PYCICLE_RANDOM}.sh"
)

# wipe the temp file job script
file(REMOVE "${PYCICLE_ROOT}/build/ctest-slurm-${PYCICLE_RANDOM}.sh")
