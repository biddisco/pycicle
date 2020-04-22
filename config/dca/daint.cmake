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
set(PYCICLE_JOB_LAUNCH    "slurm")
# for each PR do N builds
set(PYCICLE_BUILDS_PER_PR "1")

#######################################################################
# Vars passed to CTest
#######################################################################
set(CTEST_CMAKE_GENERATOR "Unix Makefiles")
set(CTEST_TEST_TIMEOUT    "600")
set(BUILD_PARALLELISM     "16")

#######################################################################
# testing with MPI and Cuda needs 1 node per GPU
#######################################################################
if (DCA_WITH_MPI AND DCA_WITH_CUDA AND DCA_WITH_TESTS_STOCHASTIC)
    set(TEST_NUM_NODES 32)
elseif (DCA_WITH_MPI AND DCA_WITH_CUDA)
    set(TEST_NUM_NODES 8)
else()
    set(TEST_NUM_NODES 1)
endif()

#######################################################################
# Machine specific options
#######################################################################
PYCICLE_CMAKE_OPTION(CTEST_SITE       "daint[]")
PYCICLE_CMAKE_OPTION(CMAKE_BUILD_TYPE "Debug[D]")
PYCICLE_CMAKE_OPTION(DCA_WITH_HPX     "ON[HPX]")

# If MPI is enabled, set srun as TEST_RUNNER
PYCICLE_CMAKE_DEPENDENT_OPTION(DCA_WITH_MPI "ON" TEST_RUNNER "srun[]")
# Path to HPX to use for the build if enabled
PYCICLE_CMAKE_DEPENDENT_OPTION(CMAKE_BUILD_TYPE "Release" HPX_DIR "/apps/daint/UES/biddisco/build/hpx-release/lib/cmake/HPX[]")
PYCICLE_CMAKE_DEPENDENT_OPTION(CMAKE_BUILD_TYPE "Debug"   HPX_DIR "/apps/daint/UES/biddisco/build/hpx-debug/lib/cmake/HPX[]")

# turn off stochastic tests on daint
PYCICLE_CMAKE_OPTION(DCA_WITH_TESTS_STOCHASTIC  "OFF[]")

PYCICLE_CMAKE_OPTION(DCA_HAVE_LAPACK "ON")
PYCICLE_CMAKE_OPTION(LAPACK_LIBRARIES   "/usr/lib64/libopenblas.so[]")
PYCICLE_CMAKE_OPTION(MAGMA_DIR          "/apps/daint/UES/biddisco/gcc/7.3.0/magma/2.5.2[]")
PYCICLE_CMAKE_OPTION(FFTW_ROOT          "/apps/daint/UES/biddisco/gcc/7.3.0/fftw/3.3.8[]")

#######################################################################
# Machine specific variables
#######################################################################
set(CMAKE_VER           "3.14.5")
set(GCC_VER             "7.3.0")
set(PYCICLE_BUILD_STAMP "gcc-${GCC_VER}-${PYCICLE_CDASH_STRING}")
#
set(CFLAGS           "-fPIC")
set(CXXFLAGS         "-fPIC -march=native -mtune=native -ffast-math -std=c++14")
set(LDFLAGS          "-dynamic")
set(LDCXXFLAGS       "${LDFLAGS} -std=c++14")

#######################################################################
# Extra CMake variables to pass to the cmake launch command
# ensure options (e.g.FLAGS) that have multiple args are escaped
#######################################################################
string(CONCAT CTEST_BUILD_OPTIONS ${CTEST_BUILD_OPTIONS}
    "\"-DCMAKE_CXX_FLAGS=${CXXFLAGS}\" "
    "\"-DCMAKE_C_FLAGS=${CFLAGS}\" "
    "\"-DCMAKE_EXE_LINKER_FLAGS=${LDCXXFLAGS}\" "
)

#######################################################################
# Setup anything compiler specific : this is only to make it easier
# to insert compiler GCC/clang/other related options in one place
# and could be added directly to the PYCICLE_JOB_SCRIPT_TEMPLATE
#######################################################################
set(PYCICLE_COMPILER_SETUP "
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

#######################################################################
# Setup a slurm job submission template
# note that this is intentionally multiline
#######################################################################
set(PYCICLE_JOB_SCRIPT_TEMPLATE "#!/bin/bash
#SBATCH --job-name=DCA-${PYCICLE_PR}-${PYCICLE_BUILD_STAMP}
#SBATCH --time=02:00:00
#SBATCH --nodes=${TEST_NUM_NODES}
#SBATCH --exclusive
#SBATCH --constraint=gpu
#SBATCH --partition=normal
#SBATCH --output=${PYCICLE_ROOT}/build/${PYCICLE_PROJECT_NAME}-${PYCICLE_PR}-${PYCICLE_BUILD_STAMP}-${PYCICLE_RANDOM}-%j.out

export CRAYPE_LINK_TYPE=dynamic

# ---------------------
# unload or load modules that differ from the defaults on the system
# ---------------------
module unload daint-mc
module load   daint-gpu
module load   slurm
module load   CMake/${CMAKE_VER}
module load   PrgEnv-gnu
module unload gcc
module load   gcc/${GCC_VER}
module load   cudatoolkit
module load   cray-hdf5

#
# ---------------------
# Append compiler setup (defined above)
# ---------------------
${PYCICLE_COMPILER_SETUP}
"
)
