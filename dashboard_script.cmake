#  Copyright (c) 2017 John Biddiscombe
#
#  Distributed under the Boost Software License, Version 1.0. (See accompanying
#  file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)

cmake_minimum_required(VERSION 3.1 FATAL_ERROR)

#######################################################################
# For debugging this script
#######################################################################
message("In ${CMAKE_CURRENT_LIST_FILE}")
message("Project name is        : " ${PYCICLE_PROJECT_NAME})
message("Github name is         : " ${PYCICLE_GITHUB_PROJECT_NAME})
message("Github org is          : " ${PYCICLE_GITHUB_ORGANISATION})
message("Github user name is    : " ${PYCICLE_GITHUB_USER_LOGIN})
message("Pull request is        : " ${PYCICLE_PR})
message("PR-Branchname is       : " ${PYCICLE_BRANCH})
message("Base branch is         : " ${PYCICLE_BASE})
message("Machine name is        : " ${PYCICLE_HOST})
message("PYCICLE_ROOT is        : " ${PYCICLE_ROOT})
message("PYCICLE_CONFIG_PATH is : " ${PYCICLE_CONFIG_PATH})
message("COMPILER type is       : " ${PYCICLE_COMPILER_TYPE})
message("BOOST is               : " ${PYCICLE_BOOST})
message("Build type is          : " ${PYCICLE_BUILD_TYPE})

#######################################################################
# Load machine specific settings
# This is where the main machine config file is read in and params set
#######################################################################
message("${CMAKE_CURRENT_LIST_DIR}")
message("getting project settings ${PYCICLE_CONFIG_PATH}/${PYCICLE_PROJECT_NAME}.cmake")
include(${PYCICLE_CONFIG_PATH}/${PYCICLE_PROJECT_NAME}.cmake)
include(${PYCICLE_CONFIG_PATH}/${PYCICLE_HOST}.cmake)

#######################################################################
# a function that calls ctest_submit - only used to make
# debugging a bit simpler by allowing us to disable submits
#######################################################################
function(pycicle_submit)
#  if(NOT DEBUG_MODE)
    ctest_submit(${ARGN})
#  endif()
endfunction()

#######################################################################
# All the rest below here should not need changes
#######################################################################
set(PYCICLE_SRC_ROOT       "${PYCICLE_ROOT}/src")
set(PYCICLE_BUILD_ROOT     "${PYCICLE_ROOT}/build")
set(PYCICLE_LOCAL_GIT_COPY "${PYCICLE_ROOT}/repos/${PYCICLE_GITHUB_PROJECT_NAME}")

set(PYCICLE_PR_ROOT          "${PYCICLE_SRC_ROOT}/${PYCICLE_PROJECT_NAME}-${PYCICLE_PR}")
set(CTEST_SOURCE_DIRECTORY   "${PYCICLE_PR_ROOT}/repo")
set(PYCICLE_BINARY_DIRECTORY "${PYCICLE_BUILD_ROOT}/${PYCICLE_PROJECT_NAME}-${PYCICLE_PR}-${PYCICLE_BUILD_STAMP}")

# make sure root dir exists
file(MAKE_DIRECTORY          "${PYCICLE_PR_ROOT}/")

if ((PYCICLE_PR STREQUAL "master") OR (PYCICLE_PR STREQUAL PYCICLE_BASE))
    set(CTEST_BUILD_NAME "${PYCICLE_BRANCH}-${PYCICLE_BUILD_STAMP}")
else()
  set(CTEST_BUILD_NAME "${PYCICLE_PR}-${PYCICLE_BRANCH}-${PYCICLE_BUILD_STAMP}")
endif()

#######################################################################
# Not yet implemented memcheck/coverage/etc
#######################################################################
set(WITH_MEMCHECK FALSE)
set(WITH_COVERAGE FALSE)

#######################################################################
# setup git
#######################################################################
include(FindGit)
set(CTEST_GIT_COMMAND "${GIT_EXECUTABLE}")

#######################################################################
# First checkout, copy from $PYCICLE_ROOT/repos/$project to save
# cloning many GB's which can be a problem for large repos over on
# slow connections
#
# if $PYCICLE_ROOT/repos/$project does not exist already, then perform a
# full checkout
#######################################################################
set (make_repo_copy_ "")
if (NOT EXISTS "${CTEST_SOURCE_DIRECTORY}/.git")
  message("Configuring src repo copy from local repo cache")
  set (make_repo_copy_ "cp -r ${PYCICLE_LOCAL_GIT_COPY} ${CTEST_SOURCE_DIRECTORY}")
  if (NOT EXISTS "${PYCICLE_LOCAL_GIT_COPY}/.git")
    message("Local repo cache missing, using full clone of src repo")
    if (PYCICLE_GITHUB_ORGANISATION)
      set (make_repo_copy_ "git clone git@github.com:${PYCICLE_GITHUB_ORGANISATION}/${PYCICLE_GITHUB_PROJECT_NAME}.git ${CTEST_SOURCE_DIRECTORY}")
    elseif (PYCICLE_GITHUB_USER_LOGIN)
      set (make_repo_copy_ "git clone git@github.com:${PYCICLE_GITHUB_USER_NAME}/${PYCICLE_GITHUB_PROJECT_NAME}.git ${CTEST_SOURCE_DIRECTORY}")
    endif(DEFINED PYCICLE_GITHUB_ORGANISATION)
  endif()
  message("${make_repo_copy_}")
endif()

#####################################################################
# if this is a PR to be merged with base for testing
#####################################################################
if (NOT PYCICLE_PR STREQUAL "${PYCICLE_BASE}")
  set(CTEST_SUBMISSION_TRACK "Pull_Requests")
  set(PYCICLE_BRANCH "pull/${PYCICLE_PR}/head")
  set(GIT_BRANCH "PYCICLE_PR_${PYCICLE_PR}")
  #
  # Note: Unless configured otherwise PYCICLE_BASE="master" or the default
  #       branch of the repo
  # checkout PYCICLE_BASE, merge the PR into a new branch with the PR name
  # then checkout PYCICLE_BASE again, then set the CTEST_UPDATE_OPTIONS
  # to fetch the merged branch so that the update step shows the
  # files that are different in the branch from PYCICLE_BASE
  #
  # The below can partially fail without it being obvious,
  # the -e should stop that, but certain things like the PR Delete can Fail
  # even if nothing is wrong.

  set(WORK_DIR "${PYCICLE_PR_ROOT}")
  execute_process(
    COMMAND bash "-c" "-e" "${make_repo_copy_};"
    WORKING_DIRECTORY "${WORK_DIR}"
    OUTPUT_VARIABLE output
    ERROR_VARIABLE  error
    RESULT_VARIABLE failed
  )
  if ( failed EQUAL 1 )
    MESSAGE( FATAL_ERROR "Update failed in ${CMAKE_CURRENT_LIST_FILE}. "
      "Could not copy local repo."
      "Is your local repo specified properly?"
      "Output is ${output}"
      "Error is ${error}")
  endif ( failed EQUAL 1 )

  execute_process(
    COMMAND bash "-c" "-e"
                      "cd ${CTEST_SOURCE_DIRECTORY};
                      ${CTEST_GIT_COMMAND} branch -D ${GIT_BRANCH};"
    WORKING_DIRECTORY "${WORK_DIR}"
    OUTPUT_VARIABLE output
    ERROR_VARIABLE  error
    RESULT_VARIABLE failed
  )
  if ( failed EQUAL 1 )
    MESSAGE( "First time for ${GIT_BRANCH} update? \n"
        "Output is ${output} \n"
        "Error is ${error}")
  endif ( failed EQUAL 1 )

  MESSAGE("${make_repo_copy_}")
  execute_process(
    COMMAND bash "-c" "-e"
                       "${make_repo_copy_};
                       cd ${CTEST_SOURCE_DIRECTORY};
                       ${CTEST_GIT_COMMAND} checkout ${PYCICLE_BASE};
                       ${CTEST_GIT_COMMAND} pull origin ${PYCICLE_BASE};
                       ${CTEST_GIT_COMMAND} reset --hard origin/${PYCICLE_BASE};
                       ${CTEST_GIT_COMMAND} checkout -b ${GIT_BRANCH};
                       ${CTEST_GIT_COMMAND} pull origin ${PYCICLE_BRANCH};
                       ${CTEST_GIT_COMMAND} checkout ${PYCICLE_BASE};
                       ${CTEST_GIT_COMMAND} clean -fd;"
    WORKING_DIRECTORY "${WORK_DIR}"
    OUTPUT_VARIABLE output
    ERROR_VARIABLE  error
    RESULT_VARIABLE failed
  )
  if ( failed EQUAL 1 )
    MESSAGE( FATAL_ERROR "Update failed in ${CMAKE_CURRENT_LIST_FILE}. "
        "Can you access github from the build location?"
        "Output is ${output}"
        "Error is ${error}")
  endif ( failed EQUAL 1 )

 #${CTEST_GIT_COMMAND} checkout ${PYCICLE_BASE};
 #                        ${CTEST_GIT_COMMAND} merge --no-edit -s recursive -X theirs origin/${PYCICLE_BRANCH};"

  set(CTEST_UPDATE_OPTIONS "${CTEST_SOURCE_DIRECTORY} ${GIT_BRANCH}")
else()
  set(CTEST_SUBMISSION_TRACK "${PYCICLE_BASE}")
  set(WORK_DIR "${PYCICLE_PR_ROOT}")
  MESSAGE("just before command\n ${make_repo_copy_}")
  execute_process(
    COMMAND bash "-c" "-e"
                      "${make_repo_copy_};
                       cd ${CTEST_SOURCE_DIRECTORY};
                       ${CTEST_GIT_COMMAND} checkout ${PYCICLE_BASE};
                       ${CTEST_GIT_COMMAND} fetch origin;
                       ${CTEST_GIT_COMMAND} reset --hard;"
    WORKING_DIRECTORY "${WORK_DIR}"
    OUTPUT_VARIABLE output
    ERROR_VARIABLE  error
    RESULT_VARIABLE failed
  )
  if ( failed EQUAL 1 )
    MESSAGE( FATAL_ERROR "Update failed in ${CMAKE_CURRENT_LIST_FILE}. "
      "Command:"
      "${make_repo_copy_};
                       cd ${CTEST_SOURCE_DIRECTORY};
                       ${CTEST_GIT_COMMAND} checkout ${PYCICLE_BASE};
                       ${CTEST_GIT_COMMAND} fetch origin;
                       ${CTEST_GIT_COMMAND} reset --hard;"
      "Typical reasons : no access to github from the build location"
      "                  Some dirty files in the source tree prevents merge"
      "Output is ${output}"
      "Error is ${error}")
  endif ( failed EQUAL 1 )
endif()

#######################################################################
# Wipe build dir when starting a new build
#######################################################################
set(CTEST_BINARY_DIRECTORY "${PYCICLE_BINARY_DIRECTORY}")
message("Wiping binary directory ${CTEST_BINARY_DIRECTORY}")
ctest_empty_binary_directory(${CTEST_BINARY_DIRECTORY})

#######################################################################
# Dashboard model : use Experimental unless problems arise
#######################################################################
set(CTEST_MODEL Experimental)

#######################################################################
# INSPECT : START a fake dashboard using only configure to run inspect
#######################################################################
if (PYCICLE_PROJECT_NAME MATCHES "hpx")
  message("Initialize dashboard : ${CTEST_MODEL} ...")
  set(CTEST_BINARY_DIRECTORY "${PYCICLE_BINARY_DIRECTORY}/inspect")
  ctest_start(${CTEST_MODEL}
    TRACK "Inspect"
    "${CTEST_SOURCE_DIRECTORY}"
    "${CTEST_BINARY_DIRECTORY}"
  )

  # configure step calls inspect instead of cmake
  string(CONCAT CTEST_CONFIGURE_COMMAND
    "${PYCICLE_ROOT}/inspect/inspect ${CTEST_SOURCE_DIRECTORY}/hpx --all --text"
  )

  message("Running inspect...")
  ctest_configure()
  ctest_submit(PARTS Configure)
endif()

#######################################################################
# Reset binary directory path
#######################################################################
set(CTEST_BINARY_DIRECTORY "${PYCICLE_BINARY_DIRECTORY}")

#######################################################################
# Erase any test complete status before starting new dashboard run
# (this should have been wiped anyway by ctest_empty_binary_directory)
#######################################################################
file(REMOVE "${CTEST_BINARY_DIRECTORY}/pycicle-TAG.txt")

#######################################################################
# START dashboard
#######################################################################
message("Initialize ${CTEST_MODEL} testing...")
ctest_start(${CTEST_MODEL}
    TRACK "${CTEST_SUBMISSION_TRACK}"
    "${CTEST_SOURCE_DIRECTORY}"
    "${CTEST_BINARY_DIRECTORY}"
)

string(CONCAT CTEST_CONFIGURE_COMMAND
  " ${CMAKE_COMMAND} -DCMAKE_BUILD_TYPE=${PYCICLE_BUILD_TYPE} "
  " ${CTEST_BUILD_OPTIONS}"
  " ${CTEST_CONFIGURE_COMMAND} \"-G${CTEST_CMAKE_GENERATOR}\""
  " ${CTEST_CONFIGURE_COMMAND} \"${CTEST_SOURCE_DIRECTORY}\"")

#######################################################################
# Update dashboard
#######################################################################
message("Update source... using ${CTEST_SOURCE_DIRECTORY}")
message("CTEST_UPDATE_COMMAND:${CTEST_UPDATE_COMMAND}")
message("CTEST_UPDATE_OPTIONS:${CTEST_UPDATE_OPTIONS}")
ctest_update(RETURN_VALUE NB_CHANGED_FILES)
message("Found ${NB_CHANGED_FILES} changed file(s)")
message("CTEST_CONFIGURE_COMMAND is\n${CTEST_CONFIGURE_COMMAND}")

message("Configure...")
ctest_configure()
pycicle_submit(PARTS Update Configure)

message("Build...")
set(CTEST_BUILD_FLAGS "-j ${BUILD_PARALLELISM}")
ctest_build(TARGET ${PYCICLE_CTEST_BUILD_TARGET} )
pycicle_submit(PARTS Build)

message("Test...")
ctest_test(RETURN_VALUE test_result_ EXCLUDE "compile")
pycicle_submit(PARTS Test)

if (WITH_COVERAGE AND CTEST_COVERAGE_COMMAND)
  ctest_coverage()
endif (WITH_COVERAGE AND CTEST_COVERAGE_COMMAND)
if (WITH_MEMCHECK AND CTEST_MEMORYCHECK_COMMAND)
  ctest_memcheck()
endif (WITH_MEMCHECK AND CTEST_MEMORYCHECK_COMMAND)

# Create a file when this build has finished so that pycicle can scrape the most
# recent results and use them to update the github  pull request status
# we will get the TAG from ctest and use it to find the correct XML files
# with our Configure/Build/Test errors/warnings
execute_process(
  COMMAND bash "-c"
    "TEMP=$(head -n 1 ${PYCICLE_BINARY_DIRECTORY}/Testing/TAG);
    {
    grep '<Error>' ${PYCICLE_BINARY_DIRECTORY}/Testing/$TEMP/Configure.xml | wc -l
    grep '<Error>' ${PYCICLE_BINARY_DIRECTORY}/Testing/$TEMP/Build.xml | wc -l
    grep '<Test Status=\"failed\">' ${PYCICLE_BINARY_DIRECTORY}/Testing/$TEMP/Test.xml | wc -l
    echo $TEMP
    } > ${PYCICLE_BINARY_DIRECTORY}/pycicle-TAG.txt"
  WORKING_DIRECTORY "${PYCICLE_BINARY_DIRECTORY}"
  OUTPUT_VARIABLE output
  ERROR_VARIABLE  error
  RESULT_VARIABLE failed
)
