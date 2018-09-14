#  Copyright (c) 2017-2018 John Biddiscombe
#
#  Distributed under the Boost Software License, Version 1.0. (See accompanying
#  file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)

set(PYCICLE_GITHUB_PROJECT_NAME  "hpx")
set(PYCICLE_GITHUB_ORGANISATION  "STEllAR-GROUP")
set(PYCICLE_GITHUB_BASE_BRANCH   "master")

# CDash server settings
set(PYCICLE_CDASH_PROJECT_NAME   "HPX")
set(PYCICLE_CDASH_SERVER_NAME    "cdash.cscs.ch")
set(PYCICLE_CDASH_HTTP_PATH      "")

# project specific target to build before running tests
set(PYCICLE_CTEST_BUILD_TARGET   "tests")

# ----------------------------------------------
# define build configuration options
# ----------------------------------------------
# ===================
# Experimental syntax?
# ===================
#PYCICLE_ CONFIG_OPTION(CMAKE_BUILD_TYPE "" Debug "D" Release "R")
#PYCICLE_ CONFIG_BOOL(HPX_WITH_APEX "A" OFF ON)
#PYCICLE_ DEPENDENT_BOOL(HPX_WITH_APEX ON APEX_WITH_OTF2 "O" OFF ON)

# ===================
# build type
# ===================
PYCICLE_CMAKE_OPTION(CMAKE_BUILD_TYPE "Debug" "Release")

# ===================
# apex
# ===================
PYCICLE_CMAKE_OPTION(HPX_WITH_APEX "OFF" "ON")
PYCICLE_CMAKE_DEPENDENT_OPTION(HPX_WITH_APEX "ON" APEX_WITH_OTF2 "OFF" "ON")

# ===================
# cuda
# ===================
PYCICLE_CMAKE_OPTION(HPX_WITH_CUDA "OFF" "ON")

# ===================
# parcelport
# ===================
# keep off by default, machines can turn on selectively
PYCICLE_CMAKE_OPTION(HPX_WITH_PARCELPORT_LIBFABRIC "OFF")
PYCICLE_CMAKE_DEPENDENT_OPTION(HPX_WITH_PARCELPORT_LIBFABRIC "ON"  HPX_PARCELPORT_LIBFABRIC_WITH_LOGGING "OFF" "ON")
PYCICLE_CMAKE_DEPENDENT_OPTION(HPX_WITH_PARCELPORT_LIBFABRIC "ON"  HPX_PARCELPORT_LIBFABRIC_WITH_BOOTSTRAPPING "OFF" "ON")
PYCICLE_CMAKE_DEPENDENT_OPTION(HPX_WITH_PARCELPORT_LIBFABRIC "ON"  HPX_PARCELPORT_LIBFABRIC_WITH_PERFORMANCE_COUNTERS "OFF" "ON")
