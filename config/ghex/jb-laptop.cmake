#######################################################################
# Specific setting for this machine only
#######################################################################

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
set(CTEST_CMAKE_GENERATOR "Unix Makefiles")
set(CTEST_TEST_TIMEOUT    "500")
set(BUILD_PARALLELISM     "4")
set(PYCICLE_BUILD_STAMP   "gcc-${GCC_VERSION}-${PYCICLE_CDASH_STRING}")

# =========================================================
# override project options for this machine configuration
# =========================================================
PYCICLE_CMAKE_OPTION(CTEST_SITE  "pop-os-jb[]")
PYCICLE_CMAKE_OPTION(CMAKE_BUILD_TYPE "Debug[D]")
PYCICLE_CMAKE_OPTION(USE_GPU "OFF[]")
PYCICLE_CMAKE_DEPENDENT_OPTION(USE_GPU "ON" CUDA_HOST_COMPILER "/usr/bin/gcc-8[]")

# machine specific MPI install location
PYCICLE_CMAKE_OPTION(MPI_ROOT "/home/biddisco/apps/openmpi/4.0.2/[]")
PYCICLE_CMAKE_OPTION(MPIEXEC_PREFLAGS "--oversubscribe[]")

# machine specific Libfabric install location
PYCICLE_CMAKE_OPTION(GHEX_USE_LIBFABRIC "ON[LF]")
PYCICLE_CMAKE_DEPENDENT_OPTION(GHEX_USE_LIBFABRIC "ON" LIBFABRIC_ROOT "/home/biddisco/apps/libfabric[]")
PYCICLE_CMAKE_DEPENDENT_OPTION(GHEX_USE_LIBFABRIC "ON" GHEX_LIBFABRIC_PROVIDER "sockets[]")
PYCICLE_CMAKE_DEPENDENT_OPTION(GHEX_USE_LIBFABRIC "ON" GHEX_LIBFABRIC_MAX_EXPECTED "512[]")
PYCICLE_CMAKE_DEPENDENT_OPTION(GHEX_USE_LIBFABRIC "ON" GHEX_LIBFABRIC_MAX_SENDS "512[]")
PYCICLE_CMAKE_DEPENDENT_OPTION(GHEX_USE_LIBFABRIC "ON" GHEX_LIBFABRIC_MAX_UNEXPECTED "512[]")
PYCICLE_CMAKE_DEPENDENT_OPTION(GHEX_USE_LIBFABRIC "ON" GHEX_LIBFABRIC_MEMORY_CHUNK_SIZE "4096[]")
PYCICLE_CMAKE_DEPENDENT_OPTION(GHEX_USE_LIBFABRIC "ON" GHEX_LIBFABRIC_MEMORY_COPY_THRESHOLD "4096[]")
PYCICLE_CMAKE_DEPENDENT_OPTION(GHEX_USE_LIBFABRIC "ON" GHEX_LIBFABRIC_WITH_BOOTSTRAPPING "OFF[]")
PYCICLE_CMAKE_DEPENDENT_OPTION(GHEX_USE_LIBFABRIC "ON" GHEX_LIBFABRIC_WITH_LOGGING "ON[]")
PYCICLE_CMAKE_DEPENDENT_OPTION(GHEX_USE_LIBFABRIC "ON" GHEX_LIBFABRIC_WITH_PERFORMANCE_COUNTERS "ON[]")

PYCICLE_CMAKE_OPTION(FETCHCONTENT_SOURCE_DIR_GRIDTOOLS "/home/biddisco/src/gridtools/[]")

#######################################################################
# These are settings you can use to define anything useful
#######################################################################
#
set(INSTALL_ROOT      "/home/biddisco/apps")
#
set(CFLAGS            "-fPIC")
set(CXXFLAGS          "-fPIC -march=native -mtune=native -ffast-math -std=c++17")
set(LDFLAGS           "")
set(LDCXXFLAGS        "${LDFLAGS}")
set(BUILD_PARALLELISM "4")
set(CMAKE_COMMAND "/home/biddisco/apps/cmake/bin/cmake")
set(CMAKE_CTEST_COMMAND "/home/biddisco/apps/cmake/bin/ctest")

#######################################################################
# The string that is used to drive cmake config step
# ensure options (e.g.FLAGS) that have multiple args are escaped
#######################################################################

string(CONCAT CTEST_BUILD_OPTIONS ${CTEST_BUILD_OPTIONS}
    "\"-DCMAKE_CXX_FLAGS=${CXXFLAGS}\" "
    "\"-DCMAKE_C_FLAGS=${CFLAGS}\" "
)
