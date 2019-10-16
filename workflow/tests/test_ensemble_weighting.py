# Copyright (c) 2019 ISciences, LLC.
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

from typing import Optional, List

from test_monthly import BasicConfig


class TestMonthly(unittest.TestCase):

    def test_one_model(self):

        class SingleModelConfig(BasicConfig):
            def models(self):
                return ['CanCM4i']

            def forecast_ensemble_members(self, model: str, yearmon: str, *, lag_hours: Optional[int] = None) -> List[str]:
                return ['1', '2', '3', '4']

        smc = SingleModelConfig()
        members = list(smc.weighted_members('201901'))

        self.assertEqual(4, len(members))
        for i in range(4):
            self.assertTupleEqual(members[i], ('CanCM4i', str(i+1), 0.25))

    def test_two_models(self):

        class TwoModelConfig(BasicConfig):
            def models(self):
                return ['CFSv2', 'CanCM4i']

            def forecast_ensemble_members(self, model: str, yearmon: str, *, lag_hours: Optional[int] = None) -> List[str]:
                if model == 'CFSv2':
                    return [str(m+1) for m in range(28)]
                if model == 'CanCM4i':
                    return [str(m+1) for m in range(10)]

        tmc = TwoModelConfig()
        members = list(tmc.weighted_members('201901'))

        self.assertEqual(38, len(members))

        cfs = [m for m in members if m[0] == 'CFSv2']
        can = [m for m in members if m[0] == 'CanCM4i']

        self.assertEqual(28, len(cfs))
        self.assertEqual(10, len(can))

        for i in range(28):
            self.assertTupleEqual(cfs[i], ('CFSv2', str(i+1), 0.5/28))
        for i in range(10):
            self.assertTupleEqual(can[i], ('CanCM4i', str(i+1), 0.5/10))

