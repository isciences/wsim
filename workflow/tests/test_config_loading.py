# Copyright (c) 2022 ISciences, LLC.
# All rights reserved.
#
# WSIM is licensed under the Apache License, Version 2.0 (the "License").
# You may not use this file except in compliance with the License. You may
# obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0.
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import unittest
import tempfile
import shutil

from wsim_workflow import workflow

config_txt = """
from wsim_workflow.config_base import ConfigBase

class TestConfig(ConfigBase):
    def __init__(self, source, derived):
        pass

    def historical_years(self):
        pass

    def observed_data(self):
        return 55

    def result_fit_years(self):
        pass

    def static_data(self):
        pass

    def workspace(self):
        pass
    
config = TestConfig
"""

class TestConfigLoading(unittest.TestCase):
    def setUp(self):
        self.tempdir = tempfile.mkdtemp()

    def tearDown(self):
        shutil.rmtree(self.tempdir)

    def testConfigImport(self):
        with tempfile.NamedTemporaryFile(suffix='.py', dir=self.tempdir) as tf:
            tf.file.write(config_txt.encode('utf8'))
            tf.file.flush()

            cfg = workflow.load_config(tf.name, 'source', 'derived', {})

            self.assertEqual(cfg.observed_data(), 55)

''