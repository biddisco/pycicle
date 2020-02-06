#  Copyright (c) 2018 Peter Doak
#  Copyright (c) 2018 John Biddiscombe
#
#  Distributed under the Boost Software License, Version 1.0. (See accompanying
#  file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)

cmake_minimum_required(VERSION 3.1 FATAL_ERROR)

#######################################################################
# Boilerplate macros we need
#######################################################################
include(${CMAKE_CURRENT_LIST_DIR}/dashboard_macros.cmake)

#######################################################################
# For debugging this script
#######################################################################
message("CMAKE_CURRENT_LIST_DIR  ${CMAKE_CURRENT_LIST_DIR}")
message("CMAKE_CURRENT_LIST_FILE ${CMAKE_CURRENT_LIST_FILE}")
#
message("Project name     " ${PYCICLE_PROJECT_NAME})
message("Github name      " ${PYCICLE_GITHUB_PROJECT_NAME})
message("Github org       " ${PYCICLE_GITHUB_ORGANISATION})
message("Github user login is    " ${PYCICLE_GITHUB_USER_LOGIN})
message("Pull request     " ${PYCICLE_PR})
message("PR-Branchname    " ${PYCICLE_BRANCH})
message("Base branch      " ${PYCICLE_BASE})
message("Machine name     " ${PYCICLE_HOST})
message("PYCICLE_ROOT     " ${PYCICLE_ROOT})
message("Debug Mode       " ${PYCICLE_DEBUG_MODE})
message("Random string    " ${PYCICLE_RANDOM})
message("CDash string     " ${PYCICLE_CDASH_STRING})
message("CMake options    " ${PYCICLE_CMAKE_OPTIONS})

expand_pycicle_cmake_options(${PYCICLE_CMAKE_OPTIONS})

message("Using config: ${PYCICLE_CONFIG_PATH}/${PYCICLE_HOST}.cmake")

#######################################################################
# Load machine specific settings
#######################################################################
include(${PYCICLE_CONFIG_PATH}/${PYCICLE_HOST}.cmake)

#######################################################################
# If any options passed in have quotes, they must be escaped
#######################################################################
string(REPLACE "\"" "\\\"" PYCICLE_CMAKE_OPTIONS_ESCAPED "${PYCICLE_CMAKE_OPTIONS}")

#######################################################################
# Generate a pbs job script and launch it
# we must pass all the parms we received through to the script
#######################################################################
string(CONCAT PYCICLE_JOB_SCRIPT_TEMPLATE ${PYCICLE_JOB_SCRIPT_TEMPLATE}
  "CXX=mpic++ ctest "
  "-S ${PYCICLE_ROOT}/pycicle/dashboard_script.cmake "
  "-DPYCICLE_ROOT=${PYCICLE_ROOT} "
  "-DPYCICLE_HOST=${PYCICLE_HOST} "
  "-DPYCICLE_PROJECT_NAME=${PYCICLE_PROJECT_NAME} "
  "-DPYCICLE_CONFIG_PATH=${PYCICLE_CONFIG_PATH} "
  "-DPYCICLE_GITHUB_PROJECT_NAME=${PYCICLE_GITHUB_PROJECT_NAME} "
  "-DPYCICLE_GITHUB_ORGANISATION=${PYCICLE_GITHUB_ORGANISATION} "
  "-DPYCICLE_GITHUB_USER_LOGIN=${PYCICLE_GITHUB_USER_LOGIN} "
  "-DPYCICLE_PR=${PYCICLE_PR} "
  "-DPYCICLE_BRANCH=${PYCICLE_BRANCH} "
  "-DPYCICLE_BASE=${PYCICLE_BASE} "
  "-DPYCICLE_DEBUG_MODE=${PYCICLE_DEBUG_MODE} "
  "-DPYCICLE_CDASH_STRING=${PYCICLE_CDASH_STRING} "
  "-DPYCICLE_CMAKE_OPTIONS=\"${PYCICLE_CMAKE_OPTIONS_ESCAPED}\" "
)

# write the job script into a temp file

if(PYCICLE_JOB_SCRIPT_TEMPLATE)
  file(WRITE "${PYCICLE_ROOT}/build/ctest-pbs-${PYCICLE_RANDOM}.sh" ${PYCICLE_JOB_SCRIPT_TEMPLATE})
else(PYCICLE_JOB_SCRIPT_TEMPLATE)
  message(FATAL_ERROR "You must have a job template to call a PBS job for CI")
endif(PYCICLE_JOB_SCRIPT_TEMPLATE)

debug_message("sbatch file contents\n"
    "${PYCICLE_JOB_SCRIPT_TEMPLATE}"
)

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
if(NOT PYCICLE_DEBUG_MODE)
  file(REMOVE "${PYCICLE_ROOT}/build/ctest-pbc-${PYCICLE_RANDOM}.sh")
endif()

