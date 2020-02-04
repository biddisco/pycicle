#  Copyright (c) 2018      Peter Doak
#  Copyright (c) 2017-2018 John Biddiscombe
#
#  Distributed under the Boost Software License, Version 1.0. (See accompanying
#  file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)

#######################################################################
# These settings control how jobs are launched and results collected
#######################################################################
# the name used to ssh into the machine
set(PYCICLE_MACHINE "localhost")
# the root location of the build/test tree on the machine
set(PYCICLE_ROOT "/home/biddisco/pycicle")
# a flag that says if the machine can send http results to cdash
set(PYCICLE_HTTP TRUE)
# Method used to launch jobs "slurm", "pbs" or "direct" supported
set(PYCICLE_JOB_LAUNCH "direct")

set(PYCICLE_COMPILER_TYPE "gcc")
set(PYCICLE_BUILD_TYPE    "Debug")

#######################################################################
# These are settings you can use to define anything useful
#######################################################################
set(GCC_VER      "9.2.1")
set(INSTALL_ROOT "/home/biddisco/apps")

set(CFLAGS     "-fPIC")
set(CXXFLAGS   "-fPIC -march=native -mtune=native -ffast-math -std=c++14")
#set(LDFLAGS    "")
#set(LDCXXFLAGS "${LDFLAGS} -std c++14")
set(BUILD_PARALLELISM "4")

set(CTEST_SITE "linux(jblaptop)")
set(CTEST_CMAKE_GENERATOR "Unix Makefiles")
set(CTEST_TEST_TIMEOUT "500")

set(PYCICLE_BUILD_STAMP "gcc-${GCC_VER}")

#######################################################################
# The string that is used to drive cmake config step
# ensure options (e.g.FLAGS) that have multiple args are escaped
#######################################################################

string(CONCAT CTEST_BUILD_OPTIONS ${CTEST_BUILD_OPTIONS}
# should be an option
      "-DCMAKE_BUILD_TYPE:STRING=Debug "
# flags (should be quoted to ensure they are passed correctly)
    "\"-DCMAKE_CXX_FLAGS=${CXXFLAGS}\" "
    "\"-DCMAKE_C_FLAGS=${CFLAGS}\" "
    "\"-DCMAKE_EXE_LINKER_FLAGS=${LDCXXFLAGS}\" "
# MKL
    " -DMKL_ROOT=/home/biddisco/intel/mkl "
# cuda
    " -DDCA_WITH_CUDA:BOOL=ON "
    " -DCUDA_HOST_COMPILER:FILEPATH=/usr/bin/gcc-8 "
# magma
    " -DDCA_WITH_MAGMA:BOOL=ON "
    " -DMAGMA_DIR:PATH=/home/biddisco/apps/magma "
# hdf5
    " -DHDF5_ROOT:PATH=/home/biddisco/apps/hdf5/1.8.12 "
# threading
    " -DDCA_WITH_THREADED_SOLVER:BOOL=ON "
# MPI
    " -DDCA_WITH_MPI:BOOL=ON "
    " -DMPI_ROOT=/home/biddisco/apps/mpich/3.3.1 "
    " -DTEST_RUNNER=/home/biddisco/apps/mpich/3.3.1/bin/mpiexec "
# HPX
    " -DHPX_DIR=/home/biddisco/build/hpx-debug/lib/cmake/HPX "
# Testing
    " -DDCA_WITH_TESTS_EXTENSIVE:BOOL=ON "
    " -DDCA_WITH_TESTS_FAST:BOOL=ON "
    " -DDCA_WITH_TESTS_PERFORMANCE:BOOL=ON "
    " -DDCA_WITH_TESTS_VALIDATION:BOOL=ON "

#    " -DFFTW_INCLUDE_DIR:PATH=/usr/include "
#    " -DFFTW_LIBRARY:FILEPATH=/usr/lib/x86_64-linux-gnu/libfftw3.so "
#    " -DDCA_THREADING_LIBRARY:STRING=STDTHREAD "
#    " -DHPX_DIR=$HOME/build/hpx-debug/lib/cmake/HPX "
#    " -DLAPACK_LIBRARIES=/opt/intel/mkl/lib/intel64/libmkl_core.so;/opt/intel/mkl/lib/intel64/libmkl_sequential.so;/opt/intel/mkl/lib/intel64/libmkl_rt.so"

)
