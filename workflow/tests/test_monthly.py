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
from wsim_workflow.paths import Vardef, DefaultWorkspace, ObservedForcing, Static
from wsim_workflow.step import Step
from wsim_workflow.monthly import monthly_observed
from wsim_workflow.workflow import get_meta_steps

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


class TestMonthly(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        cls.cfg = BasicConfig() #CFSConfig(source='/tmp/source', derived='/tmp/derived')

    def assertProduced(self, target, steps):
        self.assertTrue(any(target in step.targets for step in steps))

    def assertNotProduced(self, target, steps):
        self.assertTrue(not any(target in step.targets for step in steps))

    def test_monthly_observed(self):
        meta_steps = get_meta_steps()
        ws = self.cfg.workspace()

        steps = monthly_observed(config=self.cfg, yearmon='194801', meta_steps=meta_steps)
        self.assertProduced(ws.composite_summary(yearmon='194801', window=1), steps)
        self.assertNotProduced(ws.composite_summary(yearmon='194801', window=3), steps)

        steps = monthly_observed(config=self.cfg, yearmon='194802', meta_steps=meta_steps)
        self.assertTrue('composite_1mo_194801' in step.targets for step in steps)
        self.assertTrue('composite_3mo_194801' not in step.targets for step in steps)

        steps = monthly_observed(config=self.cfg, yearmon='194803', meta_steps=meta_steps)
        self.assertTrue('composite_1mo_194801' in step.targets for step in steps)
        self.assertTrue('composite_3mo_194803' in step.targets for step in steps)
        self.assertTrue('composite_6mo_194803' not in step.targets for step in steps)
