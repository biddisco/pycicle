#  Copyright (c) 2018      Peter Doak
#  Copyright (c) 2017-2018 John Biddiscombe
#
#  Distributed under the Boost Software License, Version 1.0. (See accompanying
#  file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)

# =========================================================
# Options that pycicle can use before invoking cmake on project
# =========================================================
##PYCICLE_ CMAKE_ OPTION(PYCICLE_COMPILER_TYPE "gcc" "clang")
##PYCICLE_ CMAKE_ DEPENDENT_OPTION(PYCICLE_COMPILER_TYPE "gcc" GCC_VERSION "5" "6" "7")

# =========================================================
# override project options for this machine configuration
# =========================================================
##PYCICLE_ CMAKE_ OPTION(CMAKE_CXX_COMPILER "/usr/bin/gcc-5" "/usr/bin/gcc-6" "/usr/bin/gcc-7" "/usr/bin/gcc")
##PYCICLE_ CMAKE_ OPTION(CMAKE_C_COMPILER   "val{CMAKE_CXX_COMPILER}")
PYCICLE_CMAKE_OPTION(CMAKE_BUILD_TYPE   "Release")
PYCICLE_CMAKE_DEPENDENT_OPTION(DCA_WITH_MPI "ON" MPI_C_COMPILER "/home/biddisco/apps/mpich/bin/mpicc")
PYCICLE_CMAKE_DEPENDENT_OPTION(DCA_WITH_MPI "ON" TEST_RUNNER "/home/biddisco/apps/mpich/bin/mpiexec")
PYCICLE_CMAKE_OPTION(DCA_WITH_CUDA "ON")

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
# These are settings you can use to define anything useful
#######################################################################
execute_process(COMMAND gcc -dumpversion OUTPUT_VARIABLE GCC_VERSION)
string(STRIP "${GCC_VERSION}" GCC_VERSION)
message("GCC version found ${GCC_VERSION}")
#
set(INSTALL_ROOT      "/home/biddisco/apps")
#
set(CFLAGS            "-fPIC")
set(CXXFLAGS          "-fPIC -march native-mtune native-ffast-math-std c++14")
set(LDFLAGS           "")
set(LDCXXFLAGS        "${LDFLAGS} -std c++14")
set(BUILD_PARALLELISM "4")
#
set(CTEST_SITE            "Arch linux(jblaptop)-gcc-${GCC_VERSION}")
set(CTEST_CMAKE_GENERATOR "Unix Makefiles")
set(CTEST_TEST_TIMEOUT    "500")

set(PYCICLE_BUILD_STAMP "gcc-${GCC_VERSION}")

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
