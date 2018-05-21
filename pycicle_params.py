class PycicleParams:
    keys = ['PYCICLE_PROJECT_NAME',
            'PYCICLE_GITHUB_PROJECT_NAME',
            'PYCICLE_GITHUB_ORGANISATION',
            'PYCICLE_PR',
            'PYCICLE_BRANCH',
            'PYCICLE_MASTER',
            'PYCICLE_HOST',
            'PYCICLE_ROOT',
            'PYCICLE_RANDOM',
            'PYCICLE_COMPILER_TYPE',
            'PYCICLE_BOOST',
            'PYCICLE_BUILD_TYPE',
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
            'PYCICLE_GITHUB_MASTER_BRANCH',
            'PYCICLE_CDASH_SERVER_NAME',
            'PYCICLE_CDASH_PROJECT_NAME',
            'PYCICLE_CDASH_HTTP_PATH',
            'PYCICLE_BUILD_STAMP',
            'PYCICLE_COMPILER_SETUP',
            'PYCICLE_SLURM',
            'PYCICLE_PBS',
            'PYCICLE_PBS_TEMPLATE']
    config_path = None

    @staticmethod
    def no_op(self, *args, **kwargs):
        pass
    
    def __init__(self, config_path=None, debug_print=PycicleParams.no_op):
        self.debug_print = debug_print

        if config_path:
            self.config_path=config_path
        else:
            current_path = os.path.dirname(os.path.realpath(__file__))
            self.config_path = current_path + '/config/' + project + '/'
            self.debug_print("pycicle expects to find configs in {}".format(self.config_path))

        
    def get_setting_for_machine(self, project, machine, setting) :
        if setting not in self.keys:
            raise ValueError("{} not a valid pycicle config parameter".format(setting))

        self.debug_print('looking for setting', setting, 'in file', self.config_path + machine + '.cmake')
        for line in f:
            m = re.findall(setting + ' *\"(.+?)\"', line)
            if m:
                return m[0]
            return None 
