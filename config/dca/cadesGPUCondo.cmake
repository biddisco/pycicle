#  Copyright (c) 2018      Peter Doak
#  Copyright (c) 2017-2018 John Biddiscombe
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
set(PYCICLE_ROOT "/lustre/or-hydra/cades-cnms/epd/DCA_PUBLIC_GPU_CI")
# a flag that says if the machine can send http results to cdash
set(PYCICLE_HTTP TRUE)
# Launch jobs using pbs rather than directly running them on the machine
set(PYCICLE_JOB_LAUNCH "pbs")

set(GCC_VER             "5.3.0")
set(PYCICLE_BUILD_STAMP "MagmaCudaP100-gcc-${GCC_VER}")
#
#set(INSTALL_ROOT     "/apps/daint/UES/6.0.UP04/HPX")
#
set(CFLAGS           "-fPIC -march=native -mtune=native -ffast-math")
set(CXXFLAGS         "-fPIC -march=native -mtune=native -ffast-math")
set(LDFLAGS          "-L/software/dev_tools/swtree/cs400_centos7.2_pe2016-08/gcc/5.3.0/centos7.2_gcc4.8.5/lib64 -Wl,-rpath,/software/dev_tools/swtree/cs400_centos7.2_pe2016-08/gcc/5.3.0/centos7.2_gcc4.8.5/lib64")
set(LDCXXFLAGS       "${LDFLAGS}")
set(FFTW_DIR         "/software/dev_tools/swtree/cs400_centos7.2_pe2016-08/fftw/3.3.5/centos7.2_gnu5.3.0")
set(HDF5_DIR         "/software/user_tools/centos-7.2.1511/cades-cnms/spack/opt/spack/linux-centos7-x86_64/gcc-5.3.0/hdf5-1.10.1-zpabgesdnfouatl7eoaw2npw5awjmawv")
set(CUDA_DIR         "/software/user_tools/centos-7.2.1511/cades-cnms/spack/opt/spack/linux-centos7-x86_64/gcc-5.3.0/cuda-8.0.61-pz7ileloxiwrc7kvi4htvwo5p7t3ugvv")
set(MAGMA_DIR        "/software/user_tools/centos-7.2.1511/cades-cnms/spack/opt/spack/linux-centos7-x86_64/gcc-5.3.0/magma-2.2.0-qy7ciibhq2avtqkddwfntzrvu5g5yh7i")
# multiline string
set(PYCICLE_COMPILER_SETUP "
    #
    spack load gcc/egooyqw
    spack load git@2.12.1
    spack load fftw/kpdartc
    spack load openssl@1.0.2o%gcc@5.3.0
    spack load cmake@3.11.3%gcc@5.3.0
    spack load mpich/6zgajlw
    spack load hdf5/4gmsnjn
    module load cuda/9.2
    spack load magma/ndhxaft
    #
    # use openmpi compiler wrappers to make MPI use easy
    export CC=mpicc
    export CXX=mpic++
    #
    #export CFLAGS=\"${CFLAGS}\"
    #export CXXFLAGS=\"${CXXFLAGS}\"
    export CUDA_TOOLKIT_ROOT_DIR=\"${CUDA_DIR}\"
    export LDFLAGS=\"${LDFLAGS}\"
    export LDCXXFLAGS=\"${LDCXXFLAGS}\"
")

set(CTEST_SITE "CENTOS7(cades-condo)-${PYCICLE_BUILD_STAMP}")
set(CTEST_CMAKE_GENERATOR "Unix Makefiles")
set(CTEST_TEST_TIMEOUT "600")
set(BUILD_PARALLELISM  "16")

#######################################################################
# The string that is used to drive cmake config step
# ensure options (e.g.FLAGS) that have multiple args are escaped
#######################################################################
#  "\"-DCMAKE_C_FLAGS=${CFLAGS}\" "


string(CONCAT CTEST_BUILD_OPTIONS ${CTEST_BUILD_OPTIONS}
    "\"-DCMAKE_CXX_COMPILER=mpic++\" "
    "\"-DCMAKE_C_COMPILER=mpicc\" "
    "\"-DCMAKE_C_FLAGS=${CFLAGS}\" "
    "\"-DCMAKE_CXX_FLAGS=${CXXFLAGS}\" "
    "\"-DCMAKE_EXE_LINKER_FLAGS=-L/software/user_tools/centos-7.2.1511/cades-cnms/spack/opt/spack/linux-centos7-x86_64/gcc-8.2.0/gcc-6.5.0-egooyqwfmyg6msi5xykwsvniotp774yx/lib64 -Wl,-rpath,/software/user_tools/centos-7.2.1511/cades-cnms/spack/opt/spack/linux-centos7-x86_64/gcc-8.2.0/gcc-6.5.0-egooyqwfmyg6msi5xykwsvniotp774yx/lib64\" "
    "\"-DDCA_WITH_THREADED_SOLVER:BOOL=ON\" "
    "\"-DDCA_WITH_MPI:BOOL=ON\" "
    "\"-DDCA_WITH_TESTS_FAST:BOOL=ON\" "
    "\"-DDCA_WITH_TESTS_PERFORMANCE:BOOL=ON\" "
    "\"-DTEST_RUNNER=mpirun\" "
    "\"-DMPIEXEC_PREFLAGS='-launcher fork -rmk pbs'\" "
    "\"-DFFTW_INCLUDE_DIR=${FFTW_DIR}/include\" "
    "\"-DFFTW_LIBRARY=${FFTW_DIR}/lib/libfftw3.a\" "
    "\"-DHDF5_ROOT=${HDF5_DIR}\" "
    "\"-DMPIEXEC_NUMPROC_FLAG=-np\" "
    "\"-DDCA_WITH_CUDA=ON\" "
    "\"-DCUDA_GPU_ARCH=sm_60\" "
    "\"-DCUDA_TOOLKIT_ROOT_DIR=${CUDA_DIR}\" "
    "\"-DMAGMA_DIR=${MAGMA_DIR}\" "
    )

#######################################################################
# Setup a slurm job submission template
# note that this is intentionally multiline
#######################################################################
set(PYCICLE_JOB_SCRIPT_TEMPLATE "#!/bin/bash
#PBS -S /bin/bash
#PBS -N DCA-${PYCICLE_PR}-${PYCICLE_BUILD_STAMP}
#PBS -l nodes=1:ppn=36:gpu_p100
#PBS -l walltime=02:00:00
#PBS -q	gpu_p100
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
