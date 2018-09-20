#  Copyright (c) 2017-2018 John Biddiscombe
#
#  Distributed under the Boost Software License, Version 1.0. (See accompanying
#  file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)

#######################################################################
# These settings control how jobs are launched and results collected
#######################################################################
# the name used to ssh into the machine
set(PYCICLE_MACHINE "127.0.0.1")
# the root location of the build/test tree on the machine
set(PYCICLE_ROOT "/home/biddisco/pycicle")
# a flag that says if the machine can send http results to cdash
set(PYCICLE_HTTP TRUE)
# Method used to launch jobs "slurm", "pbs" or "direct" supported
set(PYCICLE_JOB_LAUNCH "debug")
# Number of builds that will be triggered for each PR
set(PYCICLE_BUILDS_PER_PR "1")

#######################################################################
# These are settings you can use to define anything useful
#######################################################################
set(GCC_VER        "8.2.0")
set(BOOST_VER      "1.65.0")
set(BOOST_COMPILER "gcc82")
set(HWLOC_VER      "1.11.8")
set(JEMALLOC_VER   "5.0.1")
set(OTF2_VER       "2.0")
set(PAPI_VER       "5.5.1")
set(BOOST_SUFFIX   "1_65_0")

set(INSTALL_ROOT     "/home/biddisco/apps")
set(BOOST_ROOT       "${INSTALL_ROOT}/boost/${BOOST_VER}")
set(HWLOC_ROOT       "${INSTALL_ROOT}/hwloc/${HWLOC_VER}")
set(JEMALLOC_ROOT    "${INSTALL_ROOT}/jemalloc/${JEMALLOC_VER}")
set(OTF2_ROOT        "${INSTALL_ROOT}/otf2/${OTF2_VER}")
set(PAPI_ROOT        "${INSTALL_ROOT}/papi/${PAPI_VER}")
set(PAPI_INCLUDE_DIR "${INSTALL_ROOT}/papi/${PAPI_VER}/include")
set(PAPI_LIBRARY     "${INSTALL_ROOT}/papi/${PAPI_VER}/lib/libpfm.so")

set(CFLAGS                "-fPIC")
set(CXXFLAGS              "-fPIC -march native-mtune native-ffast-math-std c++14")
set(LDFLAGS               "")
set(LDCXXFLAGS            "${LDFLAGS} -std c++14")
set(BUILD_PARALLELISM     "8")

set(CTEST_SITE            "Arch linux(jblaptop)")
set(CTEST_CMAKE_GENERATOR "Unix Makefiles")
set(CTEST_TEST_TIMEOUT    "200")

set(PYCICLE_BUILD_STAMP   "gcc${GCC_VER}-B${BOOST_VER}-${PYCICLE_CDASH_STRING}")

#######################################################################
# The string that is used to drive cmake config step
#######################################################################
string(CONCAT CTEST_BUILD_OPTIONS
    " -DCMAKE_CXX_FLAGS=${CXXFLAGS} "
    " -DCMAKE_C_FLAGS=${CFLAGS} "
    " -DCMAKE_EXE_LINKER_FLAGS=${LDCXXFLAGS} "
    " -DHWLOC_ROOT=${HWLOC_ROOT} "
    " -DJEMALLOC_ROOT=${JEMALLOC_ROOT} "
    " -DBOOST_ROOT=${BOOST_ROOT} "
    " -DBoost_ADDITIONAL_VERSIONS=${BOOST_VER} "
    " -DBoost_COMPILER=-${BOOST_COMPILER} "
    " -DHPX_WITH_MALLOC=JEMALLOC "
)

#    " -DOTF2_ROOT=${OTF2_ROOT} "
#    " -DPAPI_ROOT=${PAPI_ROOT} "
#    " -DPAPI_INCLUDE_DIR=${PAPI_INCLUDE_DIR} "
#    " -DPAPI_LIBRARY=${PAPI_LIBRARY} "
