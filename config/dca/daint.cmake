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
set(PYCICLE_ROOT "/scratch/snx1600/biddisco/pycicle")
# a flag that says if the machine can send http results to cdash
set(PYCICLE_HTTP TRUE)
# Method used to launch jobs "slurm", "pbs" or "direct" supported
set(PYCICLE_JOB_LAUNCH    "slurm")
# for each PR do N builds
set(PYCICLE_BUILDS_PER_PR "1")

#######################################################################
# Vars passed to CTest
#######################################################################
set(CTEST_SITE            "cray(daint)")
set(CTEST_CMAKE_GENERATOR "Unix Makefiles")
set(CTEST_TEST_TIMEOUT    "240")
set(BUILD_PARALLELISM     "16")

#######################################################################
# Machine specific options
#######################################################################
# If MPI is enabled, set srun as TEST_RUNNER
PYCICLE_CMAKE_DEPENDENT_OPTION(DCA_WITH_MPI "ON" TEST_RUNNER "srun[]")
# Path to HPX to use for the build if enabled
PYCICLE_CMAKE_DEPENDENT_OPTION(DCA_WITH_HPX "ON" HPX_DIR "/scratch/snx1600/biddisco/build/hpx/lib/cmake/HPX[]")

#######################################################################
# Machine specific variables
#######################################################################
set(CMAKE_VER           "3.11.4")
set(GCC_VER             "5.3.0")
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
    "\"-DMKL_ROOT=$MKLROOT \" "
    "\"-DMAGMA_DIR=$ENV{EBROOTMAGMA}\" "
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
module load   cudatoolkit/8.0.61_2.4.3-6.0.4.0_3.1__gb475d12
module load   magma/2.2.0-CrayGNU-17.08-cuda-8.0
module load   fftw
module load   intel
module load   cray-hdf5

#
# ---------------------
# Append compiler setup (defined above)
# ---------------------
${PYCICLE_COMPILER_SETUP}
"
)
