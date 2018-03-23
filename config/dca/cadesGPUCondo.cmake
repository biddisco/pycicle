#  Copyright (c) 2018 John Biddiscombe, Peter Doak
#
#  Distributed under the Boost Software License, Version 1.0. (See accompanying
#  file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)

#######################################################################
# These settings control how jobs are launched and results collected
#######################################################################
message( WARNING "Cades GPU Condo is local only")
# the name used to ssh into the machine
set(PYCICLE_MACHINE "local")
# the root location of the build/test tree on the machine
set(PYCICLE_ROOT "/lustre/or-hydra/cades-cnms/epd/DCA_GPU_CI")
# a flag that says if the machine can send http results to cdash
set(PYCICLE_HTTP TRUE)
# Launch jobs using slurm rather than directly running them on the machine
set(PYCICLE_SLURM FALSE)
set(PYCICLE_PBS TRUE)
set(PYCICLE_COMPILER_TYPE "gcc" )
set(PYCICLE_BUILD_TYPE "Release")

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
  set(PYCICLE_BUILD_STAMP "MagmaCudaP100-gcc-${GCC_VER}")
  #
  #set(INSTALL_ROOT     "/apps/daint/UES/6.0.UP04/HPX")
  #
  set(CFLAGS           "-g -fPIC")
  set(CXXFLAGS         "-g -fPIC -march=native -mtune=native -ffast-math -std=c++14")
  set(LDFLAGS          "-L/software/dev_tools/swtree/cs400_centos7.2_pe2016-08/gcc/5.3.0/centos7.2_gcc4.8.5/lib64 -Wl,-rpath,/software/dev_tools/swtree/cs400_centos7.2_pe2016-08/gcc/5.3.0/centos7.2_gcc4.8.5/lib64")
  set(LDCXXFLAGS       "${LDFLAGS} -std=c++14")
  set(FFTW_DIR         "/software/dev_tools/swtree/cs400_centos7.2_pe2016-08/fftw/3.3.5/centos7.2_gnu5.3.0")
  set(HDF5_DIR         "/software/user_tools/centos-7.2.1511/cades-cnms/spack/opt/spack/linux-centos7-x86_64/gcc-5.3.0/hdf5-1.10.1-zpabgesdnfouatl7eoaw2npw5awjmawv/")
  set(CUDA_DIR         "/software/user_tools/centos-7.2.1511/cades-cnms/spack/opt/spack/linux-centos7-x86_64/gcc-5.3.0/cuda-8.0.61-pz7ileloxiwrc7kvi4htvwo5p7t3ugvv")
  set(MAGMA_DIR        "/software/user_tools/centos-7.2.1511/cades-cnms/spack/opt/spack/linux-centos7-x86_64/gcc-5.3.0/magma-2.2.0-qy7ciibhq2avtqkddwfntzrvu5g5yh7i")
  # multiline string
  set(PYCICLE_COMPILER_SETUP "
    #
    module load gcc/5.3.0
    spack load cmake@3.10.1%gcc@5.3.0
    spack load openmpi@3.0.0%gcc@5.3.0
    spack load hdf5@1.10.1%gcc@5.3.0
    spack load cuda@8.0.61%gcc@5.3.0
    spack load magma@2.2.0%gcc@5.3.0 +no_openmp
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
    "\"-DCMAKE_BUILD_TYPE=Release\" "
    "\"-DDCA_WITH_THREADED_SOLVER:BOOL=ON\" "
    "\"-DDCA_WITH_MPI:BOOL=ON\" "
    "\"-DDCA_WITH_TESTS_EXTENSIVE:BOOL=ON\" "
    "\"-DDCA_WITH_TESTS_FAST:BOOL=ON\" "
    "\"-DDCA_WITH_TESTS_PERFORMANCE:BOOL=ON\" "
    "\"-DTEST_RUNNER=mpirun\" "
    "\"-DFFTW_INCLUDE_DIR=/software/dev_tools/swtree/cs400/fftw/3.3.5/centos7.2_gnu5.3.0/include\" "
    "\"-DFFTW_LIBRARY=/software/dev_tools/swtree/cs400/fftw/3.3.5/centos7.2_gnu5.3.0/lib/libfftw3.a\" "
    "\"-DHDF5_ROOT=${HDF5_DIR}\" "
    "\"-DMPIEXEC_NUMPROC_FLAG=-np\" "
    "\"-DDCA_WITH_CUDA=ON\" "
    "\"-DCUDA_GPU_ARCH=sm_50\" "
    "\"-DCUDA_TOOLKIT_ROOT_DIR=${CUDA_DIR}\" "
    "\"-DMAGMA_DIR=${MAGMA_DIR}\" "
    )

#######################################################################
# Setup a slurm job submission template
# note that this is intentionally multiline
#######################################################################
set(PYCICLE_PBS_TEMPLATE "#!/bin/bash
#PBS -S /bin/bash
#PBS -m be
#PBS -N DCA-${PYCICLE_PR}-${PYCICLE_BUILD_STAMP}
#PBS -q batch
#PBS -l nodes=1:ppn=36:gpu_p100
#PBS -l walltime=02:00:00
#PBS -A ccsd
#PBS -W group_list=cades-ccsd
#PBS -l qos=std
#PBS -l naccesspolicy=singlejob

# ---------------------
# unload or load modules that differ from the defaults on the system
# ---------------------
. /software/user_tools/current/cades-cnms/spack/share/spack/setup-env.sh
#
# ---------------------
# setup stuff that might differ between compilers
# ---------------------
${PYCICLE_COMPILER_SETUP}
"
)
