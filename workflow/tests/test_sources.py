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

from wsim_workflow.data_sources import isric, stn30, gmted, ntsg_drt
from wsim_workflow.output import gnu_make
from wsim_workflow.workflow import write_makefile

def execute_steps(steps, target):
    makefile = tempfile.mkstemp()[-1]
    bindir = os.path.realpath(os.path.join(os.path.dirname(__file__), os.pardir, os.pardir))
    write_makefile(gnu_make, makefile, steps, bindir)

    return_code = subprocess.call(['make', '-f', makefile, target])

    os.remove(makefile)
    return return_code

class TestSources(unittest.TestCase):

    def setUp(self):
        self.source_dir = tempfile.mkdtemp()
        self.outfile = tempfile.mktemp()

    def tearDown(self):
        if os.path.exists(self.outfile):
            os.remove(self.outfile)
        shutil.rmtree(self.source_dir)

    @unittest.skip
    def test_isric_tawc(self):
        steps = isric.global_tawc(source_dir=self.source_dir,
                                  filename=self.outfile,
                                  resolution=1.0)

        return_code = execute_steps(steps, self.outfile)

        self.assertEqual(0, return_code)

    @unittest.skip
    def test_stn30(self):
        steps = stn30.global_flow_direction(source_dir=self.source_dir,
                                            filename=self.outfile,
                                            resolution=0.5)

        return_code = execute_steps(steps, self.outfile)

        self.assertEqual(0, return_code)

    @unittest.skip
    def test_gmted(self):
        steps = gmted.global_elevation(source_dir=self.source_dir,
                                       filename=self.outfile,
                                       resolution=2.0)

        return_code = execute_steps(steps, self.outfile)

        self.assertEqual(0, return_code)


    @unittest.skip
    def test_ntsg_drt(self):
        steps = ntsg_drt.global_flow_direction(filename=self.outfile, resolution=0.25)

        return_code = execute_steps(steps, self.outfile)

        self.assertEqual(0, return_code)

