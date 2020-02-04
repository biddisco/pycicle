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
# for each PR do N builds
set(PYCICLE_BUILDS_PER_PR "1")

#######################################################################
# Vars passed to CTest
#######################################################################
execute_process(COMMAND gcc -dumpversion OUTPUT_VARIABLE GCC_VERSION)
string(STRIP "${GCC_VERSION}" GCC_VERSION)
message("GCC version found ${GCC_VERSION}")
#
set(CTEST_SITE            "Arch linux(jblaptop)")
set(CTEST_CMAKE_GENERATOR "Unix Makefiles")
set(CTEST_TEST_TIMEOUT    "500")
set(BUILD_PARALLELISM     "4")
set(PYCICLE_BUILD_STAMP   "gcc-${GCC_VERSION}-${PYCICLE_CDASH_STRING}")

# =========================================================
# override project options for this machine configuration
# =========================================================
PYCICLE_CMAKE_OPTION(CMAKE_BUILD_TYPE "Release[R]")
PYCICLE_CMAKE_DEPENDENT_OPTION(DCA_WITH_MPI "ON" MPI_C_COMPILER "/home/biddisco/apps/mpich/bin/mpicc[]")
PYCICLE_CMAKE_DEPENDENT_OPTION(DCA_WITH_MPI "ON" TEST_RUNNER "/home/biddisco/apps/mpich/bin/mpiexec[]")
PYCICLE_CMAKE_OPTION(DCA_WITH_CUDA "ON[Cuda]")

#######################################################################
# These are settings you can use to define anything useful
#######################################################################
#
set(INSTALL_ROOT      "/home/biddisco/apps")
#
set(CFLAGS            "-fPIC")
set(CXXFLAGS          "-fPIC -march native-mtune native-ffast-math-std c++14")
set(LDFLAGS           "")
set(LDCXXFLAGS        "${LDFLAGS} -std c++14")
set(BUILD_PARALLELISM "4")

#######################################################################
# The string that is used to drive cmake config step
# ensure options (e.g.FLAGS) that have multiple args are escaped
#######################################################################

string(CONCAT CTEST_BUILD_OPTIONS ${CTEST_BUILD_OPTIONS}
    " -DMAGMA_DIR:PATH=/home/biddisco/apps/magma "
    " -DFFTW_INCLUDE_DIR:PATH=/usr/include "
    " -DFFTW_LIBRARY:FILEPATH=/usr/lib/libfftw3.so "
    " \"-DLAPACK_LIBRARIES=/opt/intel/mkl/lib/intel64/libmkl_core.so;/opt/intel/mkl/lib/intel64/libmkl_sequential.so;/opt/intel/mkl/lib/intel64/libmkl_rt.so\""
    " -DCUDA_HOST_COMPILER:FILEPATH=/usr/bin/gcc-6 "
#    " -DDCA_THREADING_LIBRARY:STRING=STDTHREAD "
#    " -DHPX_DIR=$HOME/build/hpx-debug/lib/cmake/HPX "
)
