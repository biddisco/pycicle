#  Copyright (c) 2017-2018 John Biddiscombe
#
#  Distributed under the Boost Software License, Version 1.0. (See accompanying
#  file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)

set(PYCICLE_GITHUB_PROJECT_NAME  "hpx")
set(PYCICLE_GITHUB_ORGANISATION  "STEllAR-GROUP")
set(PYCICLE_GITHUB_BASE_BRANCH "master")

# CDash server settings
set(PYCICLE_CDASH_PROJECT_NAME   "HPX")
set(PYCICLE_CDASH_SERVER_NAME    "cdash.cscs.ch")
set(PYCICLE_CDASH_HTTP_PATH      "")

# project specific target to build before running tests
set(PYCICLE_CTEST_BUILD_TARGET   "tests")

# ----------------------------------------------
# These macros are just for syntax completeness
# ----------------------------------------------
macro(PYCICLE_CONFIG_OPTION option values)
    #message(${option} " with values " ${values})
endmacro(PYCICLE_CONFIG_OPTION)

macro(PYCICLE_DEPENDENT_OPTION option values)
    #message(${option} " with values " ${values})
endmacro(PYCICLE_DEPENDENT_OPTION)

# ----------------------------------------------
# define build configuration options
# ----------------------------------------------
# ===================
# build type
# ===================
PYCICLE_CONFIG_OPTION(CMAKE_BUILD_TYPE Debug Release)

# ===================
# apex
# ===================
PYCICLE_CONFIG_OPTION(HPX_WITH_APEX OFF ON)
PYCICLE_DEPENDENT_OPTION(HPX_WITH_APEX ON APEX_WITH_OTF2 OFF ON)

# ===================
# cuda
# ===================
PYCICLE_CONFIG_OPTION(HPX_WITH_CUDA OFF ON)

# ===================
# parcelport
# ===================
PYCICLE_CONFIG_OPTION(HPX_WITH_PARCELPORT_LIBFABRIC OFF ON)
PYCICLE_DEPENDENT_OPTION(HPX_WITH_PARCELPORT_LIBFABRIC ON  HPX_PARCELPORT_LIBFABRIC_WITH_LOGGING OFF ON)
PYCICLE_DEPENDENT_OPTION(HPX_WITH_PARCELPORT_LIBFABRIC ON  HPX_PARCELPORT_LIBFABRIC_WITH_BOOTSTRAPPING OFF ON)
PYCICLE_DEPENDENT_OPTION(HPX_WITH_PARCELPORT_LIBFABRIC ON  HPX_PARCELPORT_LIBFABRIC_WITH_PERFORMANCE_COUNTERS OFF ON)

