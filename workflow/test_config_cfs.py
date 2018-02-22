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

from config_cfs import CFSConfig

class TestStep(unittest.TestCase):
    source = '/tmp/source'
    derived = '/tmp/derived'

    def test_ensemble_selection(self):
        config = CFSConfig(self.source, self.derived)

        members = config.forecast_ensemble_members('201701')
        dates = set(m[:8] for m in members)

        self.assertEqual(28, len(members))
        self.assertSetEqual(dates, {'20170125', '20170126', '20170127', '20170128', '20170129', '20170130', '20170131'})

    def test_history_length(self):
        config = CFSConfig(self.source, self.derived)

        self.assertEqual(60, len(config.result_fit_years()))


