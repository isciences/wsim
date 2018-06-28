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

from wsim_workflow.config_base import ConfigBase
from wsim_workflow.spinup import *
from wsim_workflow.dates import parse_yearmon
from wsim_workflow.paths import Vardef, DefaultWorkspace, ObservedForcing, Static

class FakeForcing(ObservedForcing):

    def p_wetdays(self, *, yearmon):
        year, mon = parse_yearmon(yearmon)
        if year >= 1979:
            return Vardef('wetdays_{}.tif'.format(yearmon), '1')
        else:
            return Vardef('wetdays_norms_{}.tif'.format(mon), '1')

    def precip_monthly(self, *, yearmon):
        return Vardef('precip_{}.tif'.format(yearmon), '1')

    def temp_monthly(self, *, yearmon):
        return Vardef('temp_{}.tif'.format(yearmon), '1')

class BasicConfig(ConfigBase):

    def historical_years(self):
        return range(1948, 2018) # 1948-2017

    def result_fit_years(self):
        return range(1950, 2010) # 1950-2009

    def observed_data(self):
        return FakeForcing()

    def static_data(self):
        return Static('fake')

    def workspace(self):
        return DefaultWorkspace('tmp')

class TestSpinup(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        cls.cfg = BasicConfig() #CFSConfig(source='/tmp/source', derived='/tmp/derived')

    def test_compute_climate_norms(self):
        steps = compute_climate_norms(self.cfg)

        years_of_t_p = len(self.cfg.historical_years())
        years_of_wetdays = len(list(y for y in self.cfg.historical_years() if y >= 1979))

        self.assertEqual(12, len(steps))

        feb = steps[1]

        self.assertEqual(len(feb.dependencies),
                         # T * Pr over full history
                         2 * years_of_t_p + \
                         # wet day climate norms
                         1 + \
                         years_of_wetdays)
