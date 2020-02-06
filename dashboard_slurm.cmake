#  Copyright (c) 2017-2018 John Biddiscombe
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
message("Project name        " ${PYCICLE_PROJECT_NAME})
message("Github name         " ${PYCICLE_GITHUB_PROJECT_NAME})
message("Github org          " ${PYCICLE_GITHUB_ORGANISATION})
message("Github user name    " ${PYCICLE_GITHUB_USER_LOGIN})
message("Pull request        " ${PYCICLE_PR})
message("PR-Branchname       " ${PYCICLE_BRANCH})
message("Base branch         " ${PYCICLE_BASE})
message("Machine name        " ${PYCICLE_HOST})
message("PYCICLE_ROOT        " ${PYCICLE_ROOT})
message("PYCICLE_CONFIG_PATH " ${PYCICLE_CONFIG_PATH})
message("Debug Mode          " ${PYCICLE_DEBUG_MODE})
message("Random string       " ${PYCICLE_RANDOM})
message("CDash string        " ${PYCICLE_CDASH_STRING})
message("CMake options       " ${PYCICLE_CMAKE_OPTIONS})
#
set(SITE ${CTEST_SITE})
set(BUILDNAME ${CTEST_BUILD_NAME})
message("SITE                " ${SITE})
message("CTEST_SITE          " ${CTEST_SITE})
message("CTEST_BUILD_NAME    " ${CTEST_BUILD_NAME})

expand_pycicle_cmake_options(${PYCICLE_CMAKE_OPTIONS})

#######################################################################
# Load machine specific settings
#######################################################################
message("Loading ${PYCICLE_CONFIG_PATH}/${PYCICLE_HOST}.cmake")
include(${PYCICLE_CONFIG_PATH}/${PYCICLE_HOST}.cmake)

#######################################################################
# If any options passed in have quotes, they must be escaped
#######################################################################
string(REPLACE "\"" "\\\"" PYCICLE_CMAKE_OPTIONS_ESCAPED "${PYCICLE_CMAKE_OPTIONS}")

#######################################################################
# Generate a slurm job script and launch it
# we must pass all the parms we received through to the script
#######################################################################
string(CONCAT PYCICLE_JOB_SCRIPT_TEMPLATE ${PYCICLE_JOB_SCRIPT_TEMPLATE}
  "ctest " "${EXTRA_CTEST_DEBUG} "
  "-S ${PYCICLE_ROOT}/pycicle/dashboard_script.cmake "
  "-DPYCICLE_ROOT=${PYCICLE_ROOT} "
  "-DPYCICLE_CONFIG_PATH=${PYCICLE_CONFIG_PATH} "
  "-DPYCICLE_HOST=${PYCICLE_HOST} "
  "-DPYCICLE_PROJECT_NAME=${PYCICLE_PROJECT_NAME} "
  "-DPYCICLE_GITHUB_PROJECT_NAME=${PYCICLE_GITHUB_PROJECT_NAME} "
  "-DPYCICLE_GITHUB_ORGANISATION=${PYCICLE_GITHUB_ORGANISATION} "
  "-DPYCICLE_GITHUB_USER_LOGIN=${PYCICLE_GITHUB_USER_LOGIN} "
  "-DPYCICLE_PR=${PYCICLE_PR} "
  "-DPYCICLE_BRANCH=${PYCICLE_BRANCH} "
  "-DPYCICLE_BASE=${PYCICLE_BASE} "
  "-DPYCICLE_DEBUG_MODE=${PYCICLE_DEBUG_MODE} "
  "-DPYCICLE_CDASH_STRING=${PYCICLE_CDASH_STRING} "
  "-DPYCICLE_CMAKE_OPTIONS=\"${PYCICLE_CMAKE_OPTIONS_ESCAPED}\" "
  "-DCTEST_BUILD_NAME=\"${CTEST_BUILD_NAME}\" "
  "-DCTEST_SITE=\"${CTEST_SITE}\" "
)

# write the job script into a temp file
file(WRITE "${PYCICLE_ROOT}/build/ctest-slurm-${PYCICLE_RANDOM}.sh"
    "${PYCICLE_JOB_SCRIPT_TEMPLATE}\n"
)
debug_message("sbatch file contents\n"
    "${PYCICLE_JOB_SCRIPT_TEMPLATE}"
)

#######################################################################
# Launch the dashboard test using slurm
# 1 Cancel any build using the same name as this one so that multiple
#   pushes to the same branch are handled cleanly
# 2 Spawn a new build
#######################################################################
message("sbatch "
    ${PYCICLE_ROOT}/build/ctest-slurm-${PYCICLE_RANDOM}.sh
)

execute_process(
  COMMAND bash "-c" "scancel $(squeue -n ${PYCICLE_PROJECT_NAME}-${PYCICLE_PR}-${PYCICLE_BUILD_STAMP} -h -o %A) > /dev/null 2>&1;
                     sbatch ${PYCICLE_ROOT}/build/ctest-slurm-${PYCICLE_RANDOM}.sh"
)

# wipe the temp file job script
if(NOT PYCICLE_DEBUG_MODE)
  file(REMOVE "${PYCICLE_ROOT}/build/ctest-slurm-${PYCICLE_RANDOM}.sh")
endif()
