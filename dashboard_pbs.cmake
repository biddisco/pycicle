#  Copyright (c) 2018 Peter Doak
#  Copyright (c) 2018 John Biddiscombe
#
#  Distributed under the Boost Software License, Version 1.0. (See accompanying
#  file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)

cmake_minimum_required(VERSION 3.1.0 FATAL_ERROR)

#######################################################################
# For debugging this script
#######################################################################
message("CMAKE_CURRENT_LIST_DIR  ${CMAKE_CURRENT_LIST_DIR}")
message("CMAKE_CURRENT_LIST_FILE ${CMAKE_CURRENT_LIST_FILE}")
#
message("Project name is  " ${PYCICLE_PROJECT_NAME})
message("Github name is   " ${PYCICLE_GITHUB_PROJECT_NAME})
message("Github org is    " ${PYCICLE_GITHUB_ORGANISATION})
message("Pull request is  " ${PYCICLE_PR})
message("PR-Branchname is " ${PYCICLE_BRANCH})
message("base branch is   " ${PYCICLE_BASE})
message("Machine name is  " ${PYCICLE_HOST})
message("PYCICLE_ROOT is  " ${PYCICLE_ROOT})
message("Random string is " ${PYCICLE_RANDOM})
message("CMake options    " ${PYCICLE_CMAKE_OPTIONS})

#######################################################################
# Load machine specific settings
#######################################################################
message("Loading ${CMAKE_CURRENT_LIST_DIR}/config/${PYCICLE_PROJECT_NAME}/${PYCICLE_HOST}.cmake")
include(${CMAKE_CURRENT_LIST_DIR}/config/${PYCICLE_PROJECT_NAME}/${PYCICLE_HOST}.cmake)

#######################################################################
# Generate a pbs job script and launch it
# we must pass all the parms we received through to the slurm script
#######################################################################
set(PYCICLE_JOB_SCRIPT_TEMPLATE ${PYCICLE_JOB_SCRIPT_TEMPLATE}
  "CXX=mpic++ ctest "
  "-S ${PYCICLE_ROOT}/pycicle/dashboard_script.cmake "
  "-DPYCICLE_ROOT=${PYCICLE_ROOT} "
  "-DPYCICLE_HOST=${PYCICLE_HOST} "
  "-DPYCICLE_PROJECT_NAME=${PYCICLE_PROJECT_NAME} "
  "-DPYCICLE_GITHUB_PROJECT_NAME=${PYCICLE_GITHUB_PROJECT_NAME} "
  "-DPYCICLE_GITHUB_ORGANISATION=${PYCICLE_GITHUB_ORGANISATION} "
  "-DPYCICLE_PR=${PYCICLE_PR} "
  "-DPYCICLE_BRANCH=${PYCICLE_BRANCH} "
  "-DPYCICLE_BOOST=${PYCICLE_BOOST} "
  "-DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE} "
  "-DPYCICLE_BASE=${PYCICLE_BASE} \n"
)

# write the job script into a temp file

if(PYCICLE_JOB_SCRIPT_TEMPLATE)
  file(WRITE "${PYCICLE_ROOT}/build/ctest-pbs-${PYCICLE_RANDOM}.sh" ${PYCICLE_JOB_SCRIPT_TEMPLATE})
else(PYCICLE_JOB_SCRIPT_TEMPLATE)
  message(FATAL_ERROR "You must have a job template to call a PBS job for CI")
endif(PYCICLE_JOB_SCRIPT_TEMPLATE)
#######################################################################
# Launch the dashboard test using pbs
# 1 Cancel any build using the same name as this one so that multiple
#   pushes to the same branch are handled cleanly
# 2 Spawn a new build
#######################################################################
message("qsub ${PYCICLE_ROOT}/build/ctest-pbs-${PYCICLE_RANDOM}.sh"
)

execute_process(
  #"qdel $(qstat -u `whoami` | awk -e \'/DCA-${PYCICLE_PR}-${PYCICLE_BUILD_STAMP}/ { print $1 }\') > /dev/null 2>&1;
  COMMAND bash "-c" "qsub ${PYCICLE_ROOT}/build/ctest-pbs-${PYCICLE_RANDOM}.sh"
  )

# wipe the temp file job script
#file(REMOVE "${PYCICLE_ROOT}/build/ctest-pbs-${PYCICLE_RANDOM}.sh")
