#  Copyright (c) 2017-2018 John Biddiscombe
#
#  Distributed under the Boost Software License, Version 1.0. (See accompanying
#  file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)

# Github settings
set(PYCICLE_GITHUB_PROJECT_NAME  "DCA")
set(PYCICLE_GITHUB_ORGANISATION  "CompFUSE")
set(PYCICLE_GITHUB_BASE_BRANCH   "master")

# CDash server settings
set(PYCICLE_CDASH_PROJECT_NAME   "DCA")
set(PYCICLE_CDASH_SERVER_NAME    "cdash.cscs.ch")
set(PYCICLE_CDASH_HTTP_PATH      "")

# project specific target to build before running tests
set(PYCICLE_CTEST_BUILD_TARGET   "all")

# for each PR we would like 2 build using generated options
set(PYCICLE_BUILDS_PER_PR "2")

# ----------------------------------------------
# These macros are just for syntax completeness
# ----------------------------------------------
macro(PYCICLE_CONFIG_OPTION option values)
endmacro(PYCICLE_CONFIG_OPTION)

macro(PYCICLE_DEPENDENT_OPTION option values)
endmacro(PYCICLE_DEPENDENT_OPTION)

# ----------------------------------------------
# define build configuration options
# ----------------------------------------------
# ===================
# build type
# ===================
PYCICLE_CONFIG_OPTION(CMAKE_BUILD_TYPE Debug Release)

# ===================
# Testing configs
# ===================
# if building release mode, allow performance tests to be on/off
# if building debug mode, allow fast and extensive tests (they use assert)
PYCICLE_DEPENDENT_OPTION(CMAKE_BUILD_TYPE Release DCA_WITH_TESTS_PERFORMANCE ON)
PYCICLE_DEPENDENT_OPTION(CMAKE_BUILD_TYPE Debug   DCA_WITH_TESTS_FAST        ON)
PYCICLE_DEPENDENT_OPTION(CMAKE_BUILD_TYPE Debug   DCA_WITH_TESTS_EXTENSIVE   ON)
PYCICLE_DEPENDENT_OPTION(CMAKE_BUILD_TYPE Debug   DCA_WITH_TESTS_VALIDATION  ON)

# ===================
# parallelism and concurrency
# ===================
PYCICLE_CONFIG_OPTION(DCA_WITH_THREADED_SOLVER ON OFF)
PYCICLE_CONFIG_OPTION(DCA_WITH_MPI             ON OFF)

# ===================
# profiling
# ===================
PYCICLE_CONFIG_OPTION(DCA_PROFILER None Counting) # PAPI

