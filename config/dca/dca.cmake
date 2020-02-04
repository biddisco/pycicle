#  Copyright (c) 2017-2018 John Biddiscombe
#
#  Distributed under the Boost Software License, Version 1.0. (See accompanying
#  file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)

# ----------------------------------------------
# Github settings
set(PYCICLE_GITHUB_PROJECT_NAME  "DCA")
set(PYCICLE_GITHUB_ORGANISATION  "CompFUSE")
set(PYCICLE_GITHUB_BASE_BRANCH   "master")

# ----------------------------------------------
# CDash server settings
set(PYCICLE_CDASH_PROJECT_NAME   "DCA")
set(PYCICLE_CDASH_SERVER_NAME    "cdash.cscs.ch")
set(PYCICLE_CDASH_HTTP_PATH      "")

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
PYCICLE_CMAKE_OPTION(CMAKE_BUILD_TYPE "Debug" "Release")

# -------------------
# Testing configs
# Should these tests be enabled/disabled based on CMAKE_BUILD_TYPE
PYCICLE_CMAKE_OPTION(DCA_WITH_TESTS_PERFORMANCE "ON")
PYCICLE_CMAKE_OPTION(DCA_WITH_TESTS_FAST        "ON")
PYCICLE_CMAKE_OPTION(DCA_WITH_TESTS_EXTENSIVE   "ON")
PYCICLE_CMAKE_OPTION(DCA_WITH_TESTS_VALIDATION  "ON")
PYCICLE_CMAKE_OPTION(DCA_WITH_TESTS_STOCHASTIC  "ON")

# -------------------
# parallelism and concurrency
PYCICLE_CMAKE_OPTION(DCA_WITH_THREADED_SOLVER "ON" "OFF")
PYCICLE_CMAKE_OPTION(DCA_WITH_MPI             "ON" "OFF")

# -------------------
# profiling, solver, RNG, others
PYCICLE_CMAKE_OPTION(DCA_PROFILER       "None" "Counting") # PAPI?
PYCICLE_CMAKE_OPTION(DCA_CLUSTER_SOLVER "CT-AUX" "SS-CT-HYB")
PYCICLE_CMAKE_OPTION(DCA_LATTICE        "square" "triangular" "bilayer")
PYCICLE_CMAKE_OPTION(DCA_POINT_GROUP    "D4" "C6")
PYCICLE_CMAKE_OPTION(DCA_RNG            "std::mt19937_64" "std::ranlux48") # "custom"

# -------------------
# Cuda
PYCICLE_CMAKE_OPTION(DCA_WITH_CUDA "ON" "OFF")
PYCICLE_CMAKE_DEPENDENT_OPTION(DCA_WITH_CUDA "ON" CUDA_PROPAGATE_HOST_FLAGS "OFF")

# -------------------
# These options are for testing pycicle arg passing/handling
PYCICLE_CMAKE_OPTION(RANDOM_TESTING_OPTION  "Hard to Parse" "Very Difficult")
