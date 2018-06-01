import unittest

from pycicle_params import PycicleParams

class MockArgs:
    def __init__(self):
        pass

class PycicleParamsTestCase(unittest.TestCase):
    def setUp(self):
        self.pyc_p = PycicleParams(MockArgs, config_path='test/')

class UnicodeRawTestCase(PycicleParamsTestCase):
    def runTest(self):
        test_setting = self.pyc_p.get_setting_for_machine('test', 'test_machine', 'PYCICLE_ROOT')
        self.assertIsNotNone(test_setting)

if __name__ == "__main__":
    unittest.main()
    print("testing done")
