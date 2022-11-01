# Copyright (c) 2021 ISciences, LLC.
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

from wsim_workflow.grids import *


class TestGrids(unittest.TestCase):

    def test_wgrib_def(self):
        self.assertEqual(
            GLOBAL_HALF_DEGREE.wgrib_def(),
            "-179.75:720:0.5 -89.75:360:0.5"
        )
