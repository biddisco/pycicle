#  Copyright (c) 2018      Peter Doak
#  Copyright (c) 2017-2018 John Biddiscombe
#
#  Distributed under the Boost Software License, Version 1.0. (See accompanying
#  file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
#--------------------------------------------------------------------------
from __future__ import absolute_import, division, print_function, unicode_literals
import os
import sys
import re

class PycicleParamsHelper:
    @staticmethod
    def no_op(self, *args, **kwargs):
        pass

class PycicleParams:
    keys = ['PYCICLE_PROJECT_NAME',
            'PYCICLE_GITHUB_PROJECT_NAME',
            'PYCICLE_GITHUB_ORGANISATION',
            'PYCICLE_GITHUB_USER_LOGIN',
            'PYCICLE_PR',
            'PYCICLE_BRANCH',
            'PYCICLE_BASE',
            'PYCICLE_HOST',
            'PYCICLE_ROOT',
            'PYCICLE_RANDOM',
            'PYCICLE_COMPILER_TYPE',
            'PYCICLE_BOOST',
            'PYCICLE_BUILD_TYPE',
            'PYCICLE_JOB_SCRIPT_TEMPLATE',
            'PYCICLE_SRC_ROOT',
            'PYCICLE_CONFIG_PATH',
            'PYCICLE_USER_NAME',
            'PYCICLE_LOCAL_GIT_COPY',
            'PYCICLE_PR_ROOT',
            'PYCICLE_BINARY_DIRECTORY',
            'PYCICLE_PR_',
            'PYCICLE_CTEST_BUILD_TARGET',
            'PYCICLE_GITHUB_TOKEN',
            'PYCICLE_MACHINES',
            'PYCICLE_MACHINE',
            'PYCICLE_HTTP',
            'PYCICLE_JOB_LAUNCH',
            'PYCICLE_GITHUB_BASE_BRANCH',
            'PYCICLE_CDASH_SERVER_NAME',
            'PYCICLE_CDASH_PROJECT_NAME',
            'PYCICLE_CDASH_HTTP_PATH',
            'PYCICLE_CDASH_DROP_METHOD',
            'PYCICLE_BUILD_STAMP',
            'PYCICLE_COMPILER_SETUP']
    config_path = None
    remote_config_path = None

    def __init__(self, args, debug_print=PycicleParamsHelper.no_op):
        """Setup a pycicle params object using args
        config_path: where the local config files are if not in pycicle/config
        debug_print: function reference used for debug_print calls
        """
        self.debug_print = debug_print

        # test for path relative to pycicle_params.py which we assume is in dir with pycicle.py
        config_path = args.config_path
        if config_path and not '.' in config_path[0]:
            self.config_path=config_path
        elif not config_path:
            raise DeprecationWarning("Pycicle now has the default config path set in args.\n"
                                     "PycicleParams should not be constructed with config_path=None")
            sys.exit()
        else:
            current_path = os.path.dirname(os.path.realpath(__file__))
            self.config_path = os.path.join(current_path, config_path, args.project)
            self.debug_print("pycicle expects to "
                "find local configs in {}".format(self.config_path))
            self.remote_config_path = os.path.join('/pycicle/config/' , args.project)
            self.debug_print("pycicle expects to "
                "remote configs in {}".format(self.remote_config_path))

    def get_setting_for_machine(self, project, machine, setting):
        if setting not in self.keys:
            raise ValueError("{} not a valid pycicle config parameter".format(setting))
        config_file = os.path.join(self.config_path, machine) + '.cmake'
        self.debug_print('looking for setting :', setting,
                         'in file', config_file)
        with open(config_file, 'r') as f:
            for line in f:
                m = re.findall(setting + r"\s*\"(.*?)\"", line)
                if m:
                    self.debug_print('found setting       :', setting, '=', m[0])
                    return m[0]
            return None
