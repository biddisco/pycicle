#  Copyright (c) 2017-2018 John Biddiscombe
#
#  Distributed under the Boost Software License, Version 1.0. (See accompanying
#  file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)

#######################################################################
# These settings control how jobs are launched and results collected
#######################################################################
# the name used to ssh into the machine
set(PYCICLE_MACHINE "daint.cscs.ch")
# the root location of the build/test tree on the machine
set(PYCICLE_ROOT "/scratch/snx3000/biddisco/pycicle")
# a flag that says if the machine can send http results to cdash
set(PYCICLE_HTTP TRUE)
# Method used to launch jobs "slurm", "pbs" or "direct" supported
set(PYCICLE_JOB_LAUNCH "slurm")
set(PYCICLE_COMPILER_TYPE "gcc" )

set(CMAKE_VER            "3.9.1")

set(GCC_VER             "5.3.0")
set(PYCICLE_BUILD_STAMP "gcc-${GCC_VER}-Boost-${BOOST_VER}-${CMAKE_BUILD_TYPE}")
#
set(INSTALL_ROOT     "/apps/daint/UES/6.0.UP04/HPX")
set(BOOST_ROOT       "${INSTALL_ROOT}/boost/${GCC_VER}/${BOOST_VER}")
#
set(CFLAGS           "-fPIC")
set(CXXFLAGS         "-fPIC -march=native -mtune=native -ffast-math -std=c++14")
set(LDFLAGS          "-dynamic")
set(LDCXXFLAGS       "${LDFLAGS} -std=c++14")

# multiline string
set(PYCICLE_COMPILER_SETUP "
    #
    module load gcc/${GCC_VER}
    #
    # use Cray compiler wrappers to make MPI use easy
    export  CC=/opt/cray/pe/craype/default/bin/cc
    export CXX=/opt/cray/pe/craype/default/bin/CC
    #
    export CFLAGS=\"${CFLAGS}\"
    export CXXFLAGS=\"${CXXFLAGS}\"
    export LDFLAGS=\"${LDFLAGS}\"
    export LDCXXFLAGS=\"${LDCXXFLAGS}\"
")

set(PAPI_ROOT        "${INSTALL_ROOT}/papi/${PAPI_VER}")
set(PAPI_INCLUDE_DIR "${INSTALL_ROOT}/papi/${PAPI_VER}/include")
set(PAPI_LIBRARY     "${INSTALL_ROOT}/papi/${PAPI_VER}/lib/libpfm.so")

set(CTEST_SITE "cray(daint)")
set(CTEST_CMAKE_GENERATOR "Unix Makefiles")
set(CTEST_TEST_TIMEOUT "600")
set(BUILD_PARALLELISM  "32")

#######################################################################
# The string that is used to drive cmake config step
# ensure options (e.g.FLAGS) that have multiple args are escaped
#######################################################################
string(CONCAT CTEST_BUILD_OPTIONS ${CTEST_BUILD_OPTIONS}
    "\"-DCMAKE_CXX_FLAGS=${CXXFLAGS}\" "
    "\"-DCMAKE_C_FLAGS=${CFLAGS}\" "
    "\"-DCMAKE_EXE_LINKER_FLAGS=${LDCXXFLAGS}\" "
    "\"-DMKL_ROOT=$MKLROOT \" "
    "\"-DDCA_WITH_CUDA:BOOL=ON\" "
    "\"-DCUDA_PROPAGATE_HOST_FLAGS=OFF\" "
    "\"-DMAGMA_DIR=$ENV{EBROOTMAGMA}\" "
    "\"-DDCA_THREADING_LIBRARY:STRING=STDTHREAD\" "
    "\"-DDCA_WITH_THREADED_SOLVER:BOOL=ON\" "
    "\"-DDCA_WITH_MPI:BOOL=OFF\" "
    "\"-DHPX_DIR=$HOME/build/hpx-debug/lib/cmake/HPX\" "
    "\"-DDCA_WITH_TESTS_EXTENSIVE:BOOL=ON\" "
    "\"-DDCA_WITH_TESTS_FAST:BOOL=ON\" "
    "\"-DDCA_WITH_TESTS_PERFORMANCE:BOOL=ON\" "
    "\"-DDCA_WITH_TESTS_VALIDATION:BOOL=ON\" "
)

#######################################################################
# Setup a slurm job submission template
# note that this is intentionally multiline
#######################################################################
set(PYCICLE_JOB_SCRIPT_TEMPLATE "#!/bin/bash
#SBATCH --job-name=DCA-${PYCICLE_PR}-${PYCICLE_BUILD_STAMP}
#SBATCH --time=01:00:00
#SBATCH --nodes=1
#SBATCH --exclusive
#SBATCH --constraint=gpu
#SBATCH --partition=normal

# ---------------------
# unload or load modules that differ from the defaults on the system
# ---------------------
module unload daint-mc
module load   daint-gpu
module load   slurm
module load   git
module load   CMake/${CMAKE_VER}
module unload gcc
module load   gcc/${GCC_VER}
module load   cudatoolkit/9.0.103_3.7-6.0.4.1_2.1__g72b395b
module load   magma/2.2.0-CrayGNU-17.08-cuda-8.0
module load   fftw
module load   intel
module load   cray-hdf5

#
# ---------------------
# setup stuff that might differ between compilers
# ---------------------
${PYCICLE_COMPILER_SETUP}
"
)
