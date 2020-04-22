#  Copyright (c) 2017-2018 John Biddiscombe
#
#  Distributed under the Boost Software License, Version 1.0. (See accompanying
#  file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)

# ----------------------------------------------
# Github settings
set(PYCICLE_GITHUB_PROJECT_NAME  "GHEX")
set(PYCICLE_GITHUB_ORGANISATION  "")
set(PYCICLE_GITHUB_USER_LOGIN    "biddisco")
set(PYCICLE_GITHUB_BASE_BRANCH   "master")

# ----------------------------------------------
# CDash server settings
set(PYCICLE_CDASH_PROJECT_NAME   "GHEX")
set(PYCICLE_CDASH_SERVER_NAME    "cdash.cscs.ch")
#set(PYCICLE_    CDASH_HTTP_PATH      "")

# ----------------------------------------------
# project specific target to build before running tests
set(PYCICLE_CTEST_BUILD_TARGET   "all")

# ----------------------------------------------
# for each PR we would like N builds using generated options
set(PYCICLE_BUILDS_PER_PR        "1")

# ----------------------------------------------
# ----------------------------------------------
# Dashboard build configuration options
# ----------------------------------------------
# ----------------------------------------------

# -------------------
# Build type
PYCICLE_CMAKE_OPTION(CMAKE_BUILD_TYPE "Debug[D]" "Release[R]")

# -------------------
# Testing configs
PYCICLE_CMAKE_OPTION(GHEX_BUILD_BENCHMARKS      "OFF[]" )
PYCICLE_CMAKE_OPTION(GHEX_BUILD_TESTS           "ON[]"  )
PYCICLE_CMAKE_OPTION(GHEX_ENABLE_ATLAS_BINDINGS "OFF[]" )
PYCICLE_CMAKE_OPTION(GHEX_SKIP_MPICXX           "ON[]"  )

# -------------------
# transport layer
PYCICLE_CMAKE_OPTION(GHEX_USE_LIBFABRIC         "ON[LF]")
PYCICLE_CMAKE_OPTION(GHEX_USE_PMIX              "OFF[]" )
PYCICLE_CMAKE_OPTION(GHEX_USE_UCP               "OFF[]" )

# -------------------
# Cuda
PYCICLE_CMAKE_BOOLEAN_OPTION(USE_GPU "Cuda")
PYCICLE_CMAKE_DEPENDENT_OPTION(USE_GPU "ON" CUDA_PROPAGATE_HOST_FLAGS "OFF[]")
