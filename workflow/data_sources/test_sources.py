# Copyright (c) 2018 ISciences, LLC.
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

import os
import shutil
import subprocess
import tempfile
import unittest

from data_sources import isric, stn30, gmted
from makemake import write_makefile

def execute_steps(steps, target):
    makefile = tempfile.mkstemp()[-1]
    bindir = os.path.realpath(os.path.join(os.path.dirname(__file__), os.pardir, os.pardir))
    write_makefile(makefile, steps, bindir)

    return subprocess.call(['make', '-f', makefile, target])

class TestSources(unittest.TestCase):

    @unittest.skip
    def test_isric_tawc(self):
        source_dir = tempfile.mkdtemp()
        outfile = os.path.join(source_dir, 'my_tawc_file.tif')

        steps = isric.global_tawc(source_dir=source_dir,
                                  filename=outfile,
                                  resolution=1.0)

        return_code = execute_steps(steps, outfile)

        shutil.rmtree(source_dir)

        self.assertEqual(0, return_code)

    @unittest.skip
    def test_stn30(self):
        source_dir = tempfile.mkdtemp()

        steps = stn30.global_flow_direction(source_dir=source_dir,
                                            resolution=0.5)

        return_code = execute_steps(steps, os.path.join(source_dir, 'STN_30', 'g_network.asc'))

        shutil.rmtree(source_dir)

        self.assertEqual(0, return_code)

