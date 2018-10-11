#  Copyright (c) 2017 John Biddiscombe
#
#  Distributed under the Boost Software License, Version 1.0. (See accompanying
#  file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)

#######################################################################
# These settings control how jobs are launched and results collected
#######################################################################
# the name used to ssh into the machine
set(PYCICLE_MACHINE "greina.cscs.ch")
# the root location of the build/test tree on the machine
set(PYCICLE_ROOT "/scratch/biddisco/pycicle")
# a flag that says if the machine can send http results to cdash
set(PYCICLE_HTTP "TRUE")
# Method used to launch jobs "slurm", "pbs" or "direct" supported
set(PYCICLE_JOB_LAUNCH "slurm")
# Number of builds that will be triggered for each PR
set(PYCICLE_BUILDS_PER_PR "1")

#######################################################################
# Vars passed to CTest
#######################################################################
set(CTEST_SITE            "cray(daint)")
set(CTEST_SITE            "linux(greina)")
set(CTEST_CMAKE_GENERATOR "Unix Makefiles")
set(CTEST_TEST_TIMEOUT    "200")
set(BUILD_PARALLELISM     "8")

set(GCC_VER       "7.2.0")
set(BOOST_VER     "1.67.1")
set(HWLOC_VER     "2.0.2")
set(JEMALLOC_VER  "5.1.0")
set(OTF2_VER      "2.0")
set(PAPI_VER      "5.5.1")
set(BOOST_SUFFIX  "1_65_1")

#######################################################################
# Machine specific options
#######################################################################
PYCICLE_CMAKE_OPTION(PYCICLE_COMPILER_TYPE         "gcc[]")
PYCICLE_CMAKE_OPTION(HPX_WITH_PARCELPORT_MPI       "OFF[]")
PYCICLE_CMAKE_OPTION(HPX_WITH_PARCELPORT_LIBFABRIC "OFF[]")
PYCICLE_CMAKE_DEPENDENT_OPTION(HPX_WITH_PARCELPORT_LIBFABRIC "ON" HPX_PARCELPORT_LIBFABRIC_PROVIDER "gni[LFg]")
PYCICLE_CMAKE_OPTION(HPX_WITH_MAX_CPU_COUNT        "256[]")
PYCICLE_CMAKE_OPTION(HPX_WITH_MORE_THAN_64_THREADS "ON[]")
PYCICLE_CMAKE_OPTION(HPX_WITH_MALLOC               "JEMALLOC[]")
PYCICLE_CMAKE_OPTION(HPX_WITH_CUDA                 "Off[]")

set(PYCICLE_BUILD_STAMP "gcc-${GCC_VER}-Boost-${BOOST_VER}-${CMAKE_BUILD_TYPE}")

set(INSTALL_ROOT     "/users/biddisco/apps/x86/gcc")
set(BOOST_ROOT       "${INSTALL_ROOT}/boost/${BOOST_VER}")
set(HWLOC_ROOT       "${INSTALL_ROOT}/hwloc/${HWLOC_VER}")
set(JEMALLOC_ROOT    "${INSTALL_ROOT}/jemalloc/${JEMALLOC_VER}")
set(OTF2_ROOT        "${INSTALL_ROOT}/otf2/${OTF2_VER}")
set(PAPI_ROOT        "${INSTALL_ROOT}/papi/${PAPI_VER}")
set(PAPI_INCLUDE_DIR "${INSTALL_ROOT}/papi/${PAPI_VER}/include")
set(PAPI_LIBRARY     "${INSTALL_ROOT}/papi/${PAPI_VER}/lib/libpfm.so")

set(CFLAGS     "-fPIC")
set(CXXFLAGS   "-fPIC -march=native -mtune=native -ffast-math")
set(LDFLAGS    "-dynamic")
set(LDCXXFLAGS "${LDFLAGS}")

#######################################################################
# The string that is used to drive cmake config step
#######################################################################
string(CONCAT CTEST_BUILD_OPTIONS ${CTEST_BUILD_OPTIONS}
    " -DCMAKE_C_COMPILER=gcc "
    " -DCMAKE_CXX_COMPILER=g++ "
    "\"-DCMAKE_CXX_FLAGS=${CXXFLAGS}\" "
    "\"-DCMAKE_CXX_FLAGS=${CXXFLAGS}\" "
    "\"-DCMAKE_C_FLAGS=${CFLAGS}\" "
    "\"-DCMAKE_EXE_LINKER_FLAGS=${LDCXXFLAGS}\" "
    " -DHWLOC_ROOT=${HWLOC_ROOT} "
    " -DJEMALLOC_ROOT=${JEMALLOC_ROOT} "
    " -DBOOST_ROOT=${BOOST_ROOT} "
    " -DBoost_ADDITIONAL_VERSIONS=${BOOST_VER} "
    " -DBoost_COMPILER=$Boost_COMPILER "
    " -DOTF2_ROOT=${OTF2_ROOT} "
#    " -DPAPI_ROOT=${PAPI_ROOT} "
#    " -DPAPI_INCLUDE_DIR=${PAPI_INCLUDE_DIR} "
#    " -DPAPI_LIBRARY=${PAPI_LIBRARY} "
    " -DHPX_WITH_MALLOC=JEMALLOC "
)

#######################################################################
# Setup a slurm job submission template
# note that this is intentionally multiline
#######################################################################
set(PYCICLE_JOB_SCRIPT_TEMPLATE "#!/bin/bash
#SBATCH --job-name=hpx-${PYCICLE_PR}-${PYCICLE_BUILD_STAMP}
#SBATCH --time=04:00:00
#SBATCH --nodes=1
#SBATCH --exclusive
#SBATCH --partition=long
##SBATCH --distribution=cyclic:cyclic

# module command not in path on greina
source /etc/profile.d/modules.sh

# ---------------------
# unload or load modules that differ from the defaults on the system
# ---------------------
module load slurm
module load gcc/${GCC_VER}
module load cmake/3.9.6

export CC=gcc
export CXX=g++

")
