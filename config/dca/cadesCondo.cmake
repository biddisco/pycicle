#  Copyright (c) 2018      Peter Doak
#  Copyright (c) 2017-2018 John Biddiscombe
#
#  Distributed under the Boost Software License, Version 1.0. (See accompanying
#  file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)

#######################################################################
# These settings control how jobs are launched and results collected
#######################################################################
message( WARNING "Cades Condo is local only")
# the name used to ssh into the machine
set(PYCICLE_MACHINE "local")
# the root location of the build/test tree on the machine
set(PYCICLE_ROOT "/lustre/or-hydra/cades-cnms/epd/DCA_CI")
# a flag that says if the machine can send http results to cdash
set(PYCICLE_HTTP FALSE)
# Launch jobs using slurm rather than directly running them on the machine
set(PYCICLE_SLURM FALSE)
set(PYCICLE_PBS TRUE)
set(PYCICLE_COMPILER_TYPE "gcc" )
set(PYCICLE_BUILD_TYPE "Debug")

# These versions are ok for gcc or clang
set(BOOST_VER            "1.65.0")
set(HWLOC_VER            "1.11.7")
set(JEMALLOC_VER         "5.0.1")
set(OTF2_VER             "2.0")
set(PAPI_VER             "5.5.1")
set(BOOST_SUFFIX         "1_65_0")
set(CMAKE_VER            "3.9.1")

if (PYCICLE_COMPILER_TYPE MATCHES "gcc")
  set(GCC_VER             "5.3.0")
  set(PYCICLE_BUILD_STAMP "gcc-${GCC_VER}")
  #
  #set(INSTALL_ROOT     "/apps/daint/UES/6.0.UP04/HPX")
  #
  set(CFLAGS           "-g -fPIC")
  set(CXXFLAGS         "-g -fPIC -march=native -mtune=native -ffast-math -std=c++14")
  set(LDFLAGS          "")
  set(LDCXXFLAGS       "${LDFLAGS} -std=c++14")
  set(FFTW_DIR         "/software/dev_tools/swtree/cs400_centos7.2_pe2016-08/fftw/3.3.5/centos7.2_gnu5.3.0")
  set(HDF5_DIR         "/software/dev_tools/swtree/cs400_centos7.2_pe2016-08/hdf5/1.8.17/centos7.2_gnu5.3.0")
  # multiline string
  set(PYCICLE_COMPILER_SETUP "
    #
    module load PE-gnu
    module load fftw/3.3.5
    module load hdf5/1.8.17
    #module load openmpi/1.10.3
    #
    # use openmpi compiler wrappers to make MPI use easy
    export CC=mpicc
    export CXX=mpic++
    #
    export CFLAGS=\"${CFLAGS}\"
    export CXXFLAGS=\"${CXXFLAGS}\"
    export LDFLAGS=\"${LDFLAGS}\"
    export LDCXXFLAGS=\"${LDCXXFLAGS}\"
  ")

elseif(PYCICLE_COMPILER_TYPE MATCHES "clang")
endif()

# set(HWLOC_ROOT       "${INSTALL_ROOT}/hwloc/${HWLOC_VER}")
# set(JEMALLOC_ROOT    "${INSTALL_ROOT}/jemalloc/${JEMALLOC_VER}")
# set(OTF2_ROOT        "${INSTALL_ROOT}/otf2/${OTF2_VER}")
# set(PAPI_ROOT        "${INSTALL_ROOT}/papi/${PAPI_VER}")
# set(PAPI_INCLUDE_DIR "${INSTALL_ROOT}/papi/${PAPI_VER}/include")
# set(PAPI_LIBRARY     "${INSTALL_ROOT}/papi/${PAPI_VER}/lib/libpfm.so")

set(CTEST_SITE "CENTOS7(cades-condo)-${PYCICLE_BUILD_STAMP}")
set(CTEST_CMAKE_GENERATOR "Unix Makefiles")
set(CTEST_TEST_TIMEOUT "600")
set(BUILD_PARALLELISM  "16")

#######################################################################
# The string that is used to drive cmake config step
# ensure options (e.g.FLAGS) that have multiple args are escaped
#######################################################################
string(CONCAT CTEST_BUILD_OPTIONS ${CTEST_BUILD_OPTIONS}
    "\"-DCMAKE_CXX_FLAGS=${CXXFLAGS}\" "
    "\"-DCMAKE_C_FLAGS=${CFLAGS}\" "
    "\"-DCMAKE_CXX_COMPILER=mpic++\" "
    "\"-DCMAKE_C_COMPILER=mpicc\" "
    "\"-DCMAKE_EXE_LINKER_FLAGS=${LDCXXFLAGS}\" "
    "\"-DDCA_THREADING_LIBRARY:STRING=STDTHREAD\" "
    "\"-DCMAKE_BUILD_TYPE=Debug\" "
    "\"-DDCA_WITH_THREADED_SOLVER:BOOL=ON\" "
    "\"-DDCA_WITH_MPI:BOOL=ON\" "
    "\"-DDCA_WITH_TESTS_EXTENSIVE:BOOL=ON\" "
    "\"-DDCA_WITH_TESTS_FAST:BOOL=ON\" "
    "\"-DDCA_WITH_TESTS_PERFORMANCE:BOOL=OFF\" "
    "\"-DTEST_RUNNER=mpirun\" "
    "\"-DFFTW_INCLUDE_DIR=${FFTW_DIR}/include\" "
    "\"-DFFTW_LIBRARY=${FFTW_DIR}/lib/libfftw3.a\" "
    "\"-DHDF5_ROOT=${HDF5_DIR}\" "
    "\"-DMPIEXEC_NUMPROC_FLAG=-np\" "
    )
    #"\"-DDCA_WITH_TESTS_VALIDATION:BOOL=ON\" "
    # "\"-DMKL_ROOT=$MKLROOT \" "
    # "\"-DDCA_WITH_CUDA:BOOL=ON\" "
    # "\"-DCUDA_PROPAGATE_HOST_FLAGS=OFF\" 
    # "\"-DMAGMA_DIR=$ENV{EBROOTMAGMA}\" "

#######################################################################
# Setup a slurm job submission template
# note that this is intentionally multiline
#######################################################################
set(PYCICLE_PBS_TEMPLATE "#!/bin/bash
#PBS -S /bin/bash
#PBS -m be
#PBS -N DCA-${PYCICLE_PR}-${PYCICLE_BUILD_STAMP}
#PBS -q batch
#PBS -l nodes=1:ppn=32
#PBS -l walltime=01:00:00
#PBS -A ccsd
#PBS -W group_list=cades-ccsd
#PBS -l qos=std
#PBS -l naccesspolicy=singlejob

# ---------------------
# unload or load modules that differ from the defaults on the system
# ---------------------
. /software/user_tools/current/cades-cnms/spack/share/spack/setup-env.sh
module load PE-gnu
#module load openmpi/1.10.3
module load hdf5/1.8.17
spack load cmake
spack load git

#
# ---------------------
# setup stuff that might differ between compilers
# ---------------------
${PYCICLE_COMPILER_SETUP}
"
)
