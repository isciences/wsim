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

import unittest

from wsim_workflow.paths import *

class TestPaths(unittest.TestCase):

    def test_date_range(self):
        # Construct a date range by specifying begin and end dates
        self.assertEqual(
            '[201402:201703:1]',
            date_range('201402', '201703')

        )

        # Can also specify a custom step
        self.assertEqual(
            '[201402:201602:12]',
            date_range('201402', '201602', 12)
        )

        # Collapse a list of dates into a range
        self.assertEqual(
            '[201402:201406:1]',
            date_range(['201402', '201403', '201404', '201405', '201406'])
        )

    def test_gdal_dataset2filename(self):
        self.assertEqual(gdaldataset2filename("NC:outputs.nc:precip"), "outputs.nc")
        self.assertEqual(gdaldataset2filename("inputs.shp"), "inputs.shp")
