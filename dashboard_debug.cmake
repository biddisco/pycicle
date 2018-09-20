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
message("Project name     " ${PYCICLE_PROJECT_NAME})
message("Github name      " ${PYCICLE_GITHUB_PROJECT_NAME})
message("Github org       " ${PYCICLE_GITHUB_ORGANISATION})
message("Pull request     " ${PYCICLE_PR})
message("PR-Branchname    " ${PYCICLE_BRANCH})
message("base branch      " ${PYCICLE_BASE})
message("Machine name     " ${PYCICLE_HOST})
message("PYCICLE_ROOT     " ${PYCICLE_ROOT})
message("Debug Mode       " ${PYCICLE_DEBUG_MODE})
message("Random string    " ${PYCICLE_RANDOM})
message("CDash string     " ${PYCICLE_CDASH_STRING})
message("CMake options    " ${PYCICLE_CMAKE_OPTIONS})

expand_pycicle_cmake_options(${PYCICLE_CMAKE_OPTIONS})

#######################################################################
# Load machine specific settings
#######################################################################
message("Loading ${CMAKE_CURRENT_LIST_DIR}/config/${PYCICLE_PROJECT_NAME}/${PYCICLE_HOST}.cmake")
include(${CMAKE_CURRENT_LIST_DIR}/config/${PYCICLE_PROJECT_NAME}/${PYCICLE_HOST}.cmake)

#######################################################################
# If any options passed in have quotes, they must be escaped
#######################################################################
string(REPLACE "\"" "\\\"" PYCICLE_CMAKE_OPTIONS_ESCAPED "${PYCICLE_CMAKE_OPTIONS}")

#######################################################################
# Generate a slurm job script and launch it
# we must pass all the parms we received through to the slurm script
#######################################################################
string(CONCAT PYCICLE_JOB_SCRIPT_TEMPLATE
  "ctest "
  "-S ${PYCICLE_ROOT}/pycicle/dashboard_script.cmake "
  "-DPYCICLE_ROOT=${PYCICLE_ROOT} "
  "-DPYCICLE_HOST=${PYCICLE_HOST} "
  "-DPYCICLE_PROJECT_NAME=${PYCICLE_PROJECT_NAME} "
  "-DPYCICLE_GITHUB_PROJECT_NAME=${PYCICLE_GITHUB_PROJECT_NAME} "
  "-DPYCICLE_GITHUB_ORGANISATION=${PYCICLE_GITHUB_ORGANISATION} "
  "-DPYCICLE_PR=${PYCICLE_PR} "
  "-DPYCICLE_BRANCH=${PYCICLE_BRANCH} "
  "-DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE} "
  "-DPYCICLE_BASE=${PYCICLE_BASE} "
  "-DPYCICLE_DEBUG_MODE=${PYCICLE_DEBUG_MODE} "
  "-DPYCICLE_CDASH_STRING=${PYCICLE_CDASH_STRING} "
  "-DPYCICLE_CMAKE_OPTIONS=\"${PYCICLE_CMAKE_OPTIONS_ESCAPED}\" "
)

debug_message(
    "------------------------------\n"
    "Execution contents\n"
    "${PYCICLE_JOB_SCRIPT_TEMPLATE}\n"
    "------------------------------"
)

#######################################################################
# Launch the dashboard test using slurm
# 1 Cancel any build using the same name as this one so that multiple
#   pushes to the same branch are handled cleanly
# 2 Spawn a new build
#######################################################################
execute_process(
  COMMAND bash "-c" "${PYCICLE_JOB_SCRIPT_TEMPLATE}"
)
