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

    meta_steps = {name: Step.create_meta(name) for name in (
        'all_fits',
        'all_composites',
        'all_monthly_composites',
        'all_adjusted_composites',
        'all_adjusted_monthly_composites',
        'forcing_summaries',
        'results_summaries',
        'electric_power_assessment',
        'agriculture_assessment'
    )}

    def test_monthly_observed(self, meta_steps=meta_steps):
        steps = monthly_observed(config=self.cfg, yearmon='194801', meta_steps=meta_steps)
        self.assertTrue('composite_1mo_194801' in step.targets for step in steps)
        self.assertTrue('composite_3mo_194801' not in step.targets for step in steps)

        steps = monthly_observed(config=self.cfg, yearmon='194802', meta_steps=meta_steps)
        self.assertTrue('composite_1mo_194801' in step.targets for step in steps)
        self.assertTrue('composite_3mo_194801' not in step.targets for step in steps)

        steps = monthly_observed(config=self.cfg, yearmon='194803', meta_steps=meta_steps)
        self.assertTrue('composite_1mo_194801' in step.targets for step in steps)
        self.assertTrue('composite_3mo_194803' in step.targets for step in steps)
        self.assertTrue('composite_6mo_194803' not in step.targets for step in steps)
