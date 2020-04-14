#  Copyright (c) 2017 John Biddiscombe
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

expand_pycicle_cmake_options(${PYCICLE_CMAKE_OPTIONS})

#######################################################################
# Load project/machine specific settings
# This is where the main machine config file is read in and params set
#######################################################################
# include project specific settings
message("Loading project settings : ${PYCICLE_CONFIG_PATH}/${PYCICLE_PROJECT_NAME}.cmake")
include(${PYCICLE_CONFIG_PATH}/${PYCICLE_PROJECT_NAME}.cmake)

# include machine specific settings
message("Loading machine settings : ${PYCICLE_CONFIG_PATH}/${PYCICLE_HOST}.cmake")
include(${PYCICLE_CONFIG_PATH}/${PYCICLE_HOST}.cmake)

#######################################################################
# a function that calls ctest_submit - only used to make
# debugging a bit simpler by allowing us to disable submits
#######################################################################

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

message("CTEST_SOURCE_DIRECTORY ${CTEST_SOURCE_DIRECTORY}")
message("CTEST_CMAKE_GENERATOR  ${CTEST_CMAKE_GENERATOR}")
message("CTEST_TEST_TIMEOUT     ${CTEST_TEST_TIMEOUT}")
message("BUILD_PARALLELISM      ${BUILD_PARALLELISM}")

set(SITE ${CTEST_SITE})
set(BUILDNAME ${CTEST_BUILD_NAME})
message("SITE                " ${SITE})
message("CTEST_SITE          " ${CTEST_SITE})
message("CTEST_BUILD_NAME    " ${CTEST_BUILD_NAME})

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
# if this PR has been tested before, the repo will exist, so use ":"
set (make_repo_copy_ ":")
if (NOT EXISTS "${CTEST_SOURCE_DIRECTORY}/.git")
  message("Configuring src repo copy from local repo cache")
  set (make_repo_copy_ "cp -r ${PYCICLE_LOCAL_GIT_COPY} ${CTEST_SOURCE_DIRECTORY}")
  if (NOT EXISTS "${PYCICLE_LOCAL_GIT_COPY}/.git")
    message("Local repo cache \"${PYCICLE_LOCAL_GIT_COPY}/.git\" missing, using full clone of src repo")
    if (PYCICLE_GITHUB_ORGANISATION)
      set (make_repo_copy_ "git clone git@github.com:${PYCICLE_GITHUB_ORGANISATION}/${PYCICLE_GITHUB_PROJECT_NAME}.git ${CTEST_SOURCE_DIRECTORY}")
    elseif (PYCICLE_GITHUB_USER_LOGIN)
      set (make_repo_copy_ "git clone git@github.com:${PYCICLE_GITHUB_USER_NAME}/${PYCICLE_GITHUB_PROJECT_NAME}.git ${CTEST_SOURCE_DIRECTORY}")
    endif()
  endif()
  message("${make_repo_copy_}")
endif()

#####################################################################
# if this is a PR to be merged with base for testing
# (i.e not a test of master branch on its own)
#####################################################################
if (NOT PYCICLE_PR STREQUAL "${PYCICLE_BASE}")
  set(CTEST_SUBMISSION_GROUP "Pull_Requests")
  set(PYCICLE_BRANCH "pull/${PYCICLE_PR}/head")
  set(GIT_BRANCH "PYCICLE_PR_${PYCICLE_PR}")
  #
  # Note: Unless configured otherwise PYCICLE_BASE="master" or the default
  # branch of the repo.
  # Steps
  # 1) checkout PYCICLE_BASE
  # 2) merge the PR into a new branch with the PR name
  # 3) checkout PYCICLE_BASE again
  # 4) set the CTEST_UPDATE_OPTIONS to fetch the merged branch
  # so that the CDash update shows the files that are different
  # in the branch from PYCICLE_BASE
  #
  # The below can partially fail without it being obvious,
  # the -e should stop that, but certain things like the PR Delete can Fail
  # even if nothing is wrong.

  # copy or clone the repo to our local testing location
  debug_execute_process(
    COMMAND bash "-c" "-e"
                      "${make_repo_copy_};"
    WORKING_DIRECTORY "${PYCICLE_PR_ROOT}"
    TITLE   "Copy local repo"
    MESSAGE "Could not copy local repo"
  )

  debug_execute_process(
    COMMAND bash "-c" "-e"
                      "${CTEST_GIT_COMMAND} branch -D ${GIT_BRANCH}"
    WORKING_DIRECTORY "${CTEST_SOURCE_DIRECTORY}"
    TITLE   "Delete old PR branch"
    MESSAGE "Could not delete old ${GIT_BRANCH} (first time test?)"
  )

  debug_execute_process(
    COMMAND bash "-c" "-e"
                      "echo 'Checking out base branch' &&
                       ${CTEST_GIT_COMMAND} checkout -f  ${PYCICLE_BASE} &&
                       echo 'Fetching from origin' &&
                       ${CTEST_GIT_COMMAND} fetch --all &&
                       echo 'reset --hard' &&
                       ${CTEST_GIT_COMMAND} reset --hard origin/${PYCICLE_BASE} &&
                       echo 'checkout new ${GIT_BRANCH}' &&
                       ${CTEST_GIT_COMMAND} checkout -b  ${GIT_BRANCH} &&
                       echo 'pull from ${PYCICLE_BRANCH}' &&
                       ${CTEST_GIT_COMMAND} pull origin  ${PYCICLE_BRANCH} --no-edit
                       echo 'switch back to base' &&
                       ${CTEST_GIT_COMMAND} checkout     ${PYCICLE_BASE} &&
                       echo 'clean remaining cruft' &&
                       ${CTEST_GIT_COMMAND} clean -fd"
    WORKING_DIRECTORY "${CTEST_SOURCE_DIRECTORY}"
    TITLE   "Update + merge PR branch"
    MESSAGE "Update PR failed - Can you access github from the build location?"
    FATAL
  )
  # the update command will checkout the merged PR branch
  set(CTEST_GIT_UPDATE_OPTIONS "checkout" "${GIT_BRANCH}")

else()
  #####################################################################
  # This is a just branch test and not a PR
  #####################################################################
  if ("master" STREQUAL "${PYCICLE_BASE}")
    set(CTEST_SUBMISSION_GROUP "Master")
  else()
      set(CTEST_SUBMISSION_GROUP "${PYCICLE_BASE}")
  endif()
  debug_execute_process(
    COMMAND bash "-c" "-e"
                      "${make_repo_copy_} &&
                       cd ${CTEST_SOURCE_DIRECTORY} &&
                       ${CTEST_GIT_COMMAND} checkout ${PYCICLE_BASE} &&
                       ${CTEST_GIT_COMMAND} fetch origin &&
                       ${CTEST_GIT_COMMAND} reset --hard"
    WORKING_DIRECTORY "${PYCICLE_PR_ROOT}"
    TITLE   "Checkout branch"
    MESSAGE "Branch ${PYCICLE_BASE} update failed\n\t"
            "Typical reasons : no access to github from the build location\n\t"
            "Some dirty files in the source tree prevents merge"
    FATAL
  )
  # the update command will checkout the branch
  set(CTEST_GIT_UPDATE_OPTIONS "checkout" "${PYCICLE_BASE}")
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
# Reset binary directory path
#######################################################################
set(CTEST_BINARY_DIRECTORY "${PYCICLE_BINARY_DIRECTORY}")

#######################################################################
# Erase any test complete status before starting new dashboard run
# (this should have been wiped anyway by ctest_empty_binary_directory)
#######################################################################
file(REMOVE "${CTEST_BINARY_DIRECTORY}/pycicle-TAG.txt")

#######################################################################
# Write out a notes file with our CMake build options
#######################################################################
#set(CTEST_NOTES_FILES "${PYCICLE_BINARY_DIRECTORY}/pycicle_notes.txt")
#string(REPLACE " -D" "\n-D" PYCICLE_CMAKE_OPTIONS_MULTILINE "${PYCICLE_CMAKE_OPTIONS}")
#file(WRITE "${CTEST_NOTES_FILES}" "${PYCICLE_CMAKE_OPTIONS_MULTILINE}\n" )

#######################################################################
# START dashboard
#######################################################################
message("Initialize ${CTEST_MODEL} testing...")
ctest_start(${CTEST_MODEL}
    TRACK "${CTEST_SUBMISSION_GROUP}"
    "${CTEST_SOURCE_DIRECTORY}"
    "${CTEST_BINARY_DIRECTORY}"
)

STRING_UNQUOTE(UNQUOTED_CMAKE_OPTIONS ${PYCICLE_CMAKE_OPTIONS})
if (UNQUOTED_CMAKE_OPTIONS STREQUAL "")
    set(UNQUOTED_CMAKE_OPTIONS ${PYCICLE_CMAKE_OPTIONS})
endif()

string(CONCAT CTEST_CONFIGURE_COMMAND
  " ${CMAKE_COMMAND} "
  " ${EXTRA_CTEST_DEBUG} "
  " ${PYCICLE_CMAKE_OPTIONS} "
  " ${CTEST_BUILD_OPTIONS} "
  " -DCTEST_SITE=${CTEST_SITE} "
  " -DCTEST_BUILD_NAME=${CTEST_BUILD_NAME} "
  " -DSITE=${CTEST_SITE} "
  " -DBUILDNAME=${CTEST_BUILD_NAME} "
  " \"-G${CTEST_CMAKE_GENERATOR}\" "
  " \"${CTEST_SOURCE_DIRECTORY}\"")

#######################################################################
# Update dashboard
#######################################################################

#--------------
# update step : switch to testing branch (detects changed files)
#--------------
set(CTEST_GIT_UPDATE_CUSTOM "${CTEST_GIT_COMMAND}" ${CTEST_GIT_UPDATE_OPTIONS})
message("Update source... using ${CTEST_SOURCE_DIRECTORY}\n"
        "CTEST_GIT_UPDATE_CUSTOM ${CTEST_GIT_UPDATE_CUSTOM}")
ctest_update(RETURN_VALUE NB_CHANGED_FILES)
message("Found ${NB_CHANGED_FILES} changed file(s)")

#--------------
# configure step
#--------------
message("CTEST_CONFIGURE_COMMAND is\n${CTEST_CONFIGURE_COMMAND}")
message("Configure...")
ctest_configure()
#pycicle_submit(PARTS Update Configure Notes)
debug_execute_process(
  COMMAND "${CMAKE_CTEST_COMMAND}" "${EXTRA_CTEST_DEBUG}"
    "-D" "ExperimentalSubmit" "--track" "${CTEST_SUBMISSION_GROUP}"
#    "--add-notes" "${CTEST_NOTES_FILES}"
  WORKING_DIRECTORY "${CTEST_BINARY_DIRECTORY}"
  TITLE   "Submit update step"
  MESSAGE "Update submit failed"
)

#--------------
# build step
#--------------
message("Build...")
set(CTEST_BUILD_FLAGS "-j ${BUILD_PARALLELISM}")
ctest_build(TARGET ${PYCICLE_CTEST_BUILD_TARGET} )
#pycicle_submit(PARTS Build)
debug_execute_process(
  COMMAND "${CMAKE_CTEST_COMMAND}" "${EXTRA_CTEST_DEBUG}"
    "-D"  "ExperimentalSubmit" "--track" "${CTEST_SUBMISSION_GROUP}"
  WORKING_DIRECTORY "${CTEST_BINARY_DIRECTORY}"
  TITLE   "Submit build step"
  MESSAGE "Build submit failed"
)

#--------------
# test step
#--------------
message("Test...")
ctest_test(RETURN_VALUE test_result_ EXCLUDE "compile")
#pycicle_submit(PARTS Test)
debug_execute_process(
  COMMAND "${CMAKE_CTEST_COMMAND}" "${EXTRA_CTEST_DEBUG}"
    "-D"  "ExperimentalSubmit" "--track" "${CTEST_SUBMISSION_GROUP}"
  WORKING_DIRECTORY "${CTEST_BINARY_DIRECTORY}"
  TITLE   "Submit test step"
  MESSAGE "Test submit failed"
)

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
debug_execute_process(
  COMMAND bash "-c"
    "TEMP=$(head -n 1 ${PYCICLE_BINARY_DIRECTORY}/Testing/TAG);
    {
    grep '<Error>' ${PYCICLE_BINARY_DIRECTORY}/Testing/$TEMP/Configure.xml | wc -l
    grep '<Error>' ${PYCICLE_BINARY_DIRECTORY}/Testing/$TEMP/Build.xml | wc -l
    grep '<Test Status=\"failed\">' ${PYCICLE_BINARY_DIRECTORY}/Testing/$TEMP/Test.xml | wc -l
    echo $TEMP
    } > ${PYCICLE_BINARY_DIRECTORY}/pycicle-TAG.txt"
  WORKING_DIRECTORY "${PYCICLE_BINARY_DIRECTORY}"
  TITLE   "Scrape results"
  MESSAGE "Scraping of test results failed"
)
