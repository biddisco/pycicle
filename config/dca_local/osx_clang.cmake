#  Copyright (c) 2018      Peter Doak
#  Copyright (c) 2017-2018 John Biddiscombe
#
#  Distributed under the Boost Software License, Version 1.0. (See accompanying
#  file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)

#######################################################################
# These settings control how jobs are launched and results collected
#######################################################################
message( "OSX Clang is local only")
# the name used to ssh into the machine
set(PYCICLE_MACHINE "local")
# the root location of the build/test tree on the machine
set(PYCICLE_ROOT "/Users/epd/CI/DCA")
# a flag that says if the machine can send http results to cdash
set(PYCICLE_HTTP FALSE)
# Launch jobs using slurm rather than directly running them on the machine
set(PYCICLE_SLURM FALSE)
set(PYCICLE_PBS TRUE)
set(PYCICLE_COMPILER_TYPE "clang")
set(PYCICLE_BUILD_TYPE "Debug")

# These versions are ok for gcc or clang
set(BOOST_VER            "1.65.0")
set(HWLOC_VER            "1.11.7")
set(JEMALLOC_VER         "5.0.1")
set(OTF2_VER             "2.0")
set(PAPI_VER             "5.5.1")
set(BOOST_SUFFIX         "1_65_0")
set(CMAKE_VER            "3.9.1")

if (PYCICLE_COMPILER_TYPE MATCHES "clang")
  set(CLANG_VER             "5.0.1")
  set(PYCICLE_BUILD_STAMP "clang-${CLANG_VER}")
  #

  set(PYCICLE_COMPILER_SETUP "
    #
    a_dci_env
    ")

endif(PYCICLE_COMPILER_TYPE MATCHES "clang")

set(CTEST_SITE "Highsierra(mac95788)-${PYCICLE_BUILD_STAMP}")
set(CTEST_CMAKE_GENERATOR "Unix Makefiles")
set(CTEST_TEST_TIMEOUT "600")
set(BUILD_PARALLELISM  "4")



#######################################################################
# The string that is used to drive cmake config step
# ensure options (e.g.FLAGS) that have multiple args are escaped
#######################################################################

  string(CONCAT CTEST_BUILD_OPTIONS ${CTEST_BUILD_OPTIONS}
    "\"-DCMAKE_C_COMPILER=/Users/epd/local/openmpi-1.10.7/bin/mpicc\" "
    "\"-DCMAKE_CXX_COMPILER=/Users/epd/local/openmpi-1.10.7/bin/mpic++\" "
    "\"-DCMAKE_C_FLAGS=-I/usr/local/opt/llvm/include -I/Users/epd/local/fftw-3.3.7/include\" "
    "\"-DCMAKE_EXE_LINKER_FLAGS=-L/usr/local/opt/llvm/lib -L/Users/epd/local/fftw-3.3.7/lib\" "
    "\"-DFFTW_INCLUDE_DIR=/Users/epd/local/fftw-3.3.7/include\" "
    "\"-DFFTW_LIBRARY=/Users/epd/local/fftw-3.3.7/lib/libfftw3.a\" "
    "\"-DMPIEXEC_NUMPROC_FLAG=-np\" "
    "\"-DDCA_THREADING_LIBRARY:STRING=STDTHREAD\" "
    "\"-DDCA_WITH_THREADED_SOLVER:BOOL=ON\" "
    "\"-DDCA_WITH_MPI:BOOL=ON\" "
    "\"-DDCA_WITH_TESTS_EXTENSIVE:BOOL=OFF\" "
    "\"-DDCA_WITH_TESTS_FAST:BOOL=ON\" "
    "\"-DTEST_RUNNER=/Users/epd/local/openmpi-1.10.7/bin/mpirun\" ")
