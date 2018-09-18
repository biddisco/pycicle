#  Copyright (c) 2018      Peter Doak
#  Copyright (c) 2017-2018 John Biddiscombe
#
#  Distributed under the Boost Software License, Version 1.0. (See accompanying
#  file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
#--------------------------------------------------------------------------
from __future__ import absolute_import, division, print_function, unicode_literals
import os
import re

class PycicleParamsHelper:
    @staticmethod
    def no_op(self, *args, **kwargs):
        pass

class PycicleParams:
    keys = ['PYCICLE_PROJECT_NAME',
            'PYCICLE_GITHUB_PROJECT_NAME',
            'PYCICLE_GITHUB_ORGANISATION',
            'PYCICLE_PR',
            'PYCICLE_BRANCH',
            'PYCICLE_BASE',
            'PYCICLE_HOST',
            'PYCICLE_ROOT',
            'PYCICLE_RANDOM',
            'PYCICLE_JOB_SCRIPT_TEMPLATE',
            'PYCICLE_SRC_ROOT',
            'PYCICLE_BUILD_ROOT',
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
            'PYCICLE_BUILD_STAMP',
            'PYCICLE_COMPILER_SETUP',
            'PYCICLE_CMAKE_OPTIONS',
            'PYCICLE_BUILDS_PER_PR']
    config_path = None

    def __init__(self, args, config_path=None,
                 debug_print=PycicleParamsHelper.no_op):
        """Setup a pycicle params object using args
        config_path: where the config files are if not in pycicle/config
        debug_print: function reference used for debug_print calls
        """
        self.debug_print = debug_print

        if config_path:
            self.config_path=config_path
        else:
            current_path = os.path.dirname(os.path.realpath(__file__))
            self.config_path = current_path + '/config/' + args.project + '/'
            self.debug_print("pycicle expects to "
                             "find configs in {}".format(self.config_path))

    def get_setting_from_file(self, config_file, setting):
        if setting not in self.keys:
            raise ValueError("{} not a valid pycicle config parameter".format(setting))
        self.debug_print('looking for setting :', setting,
                         'in file', config_file)
        with open(config_file, 'r') as f:
            for line in f:
                m = re.findall(setting + r"\s*\"(.*?)\"", line)
                if m:
                    self.debug_print('found setting       :', setting, '=', m[0])
                    return m[0]
            return None

    # get setting from project file
    def get_setting_for_project(self, project, machine, setting):
        config_file = self.config_path + project + '.cmake'
        return self.get_setting_from_file(config_file, setting)

    # get setting from machine file
    def get_setting_for_machine(self, project, machine, setting):
        config_file = self.config_path + machine + '.cmake'
        return self.get_setting_from_file(config_file, setting)

    # get setting from machine file if present, otherwise project file
    def get_setting_for_machine_project(self, project, machine, setting):
        config_file = self.config_path + machine + '.cmake'
        val = self.get_setting_from_file(config_file, setting)
        if val is None:
            config_file = self.config_path + project + '.cmake'
            val = self.get_setting_from_file(config_file, setting)
        return val
