#  Copyright (c) 2017-2018 John Biddiscombe, Peter Doak
#
#  Distributed under the Boost Software License, Version 1.0. (See accompanying
#  file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)

# Github settings
set(PYCICLE_GITHUB_PROJECT_NAME  "PDoakORNL/DCA")
set(PYCICLE_GITHUB_ORGANISATION  "PDoakORNL")
set(PYCICLE_GITHUB_BASE_BRANCH "gpu_trunk")
set(PYCICLE_HTTP TRUE)

# CDash server settings
set(PYCICLE_CDASH_PROJECT_NAME "DCA")
set(PYCICLE_CDASH_SERVER_NAME  "localhost:38080")
set(PYCICLE_CDASH_HTTP_PATH    "cdash")

# project specific target to build before running tests
set(PYCICLE_CTEST_BUILD_TARGET "all")
