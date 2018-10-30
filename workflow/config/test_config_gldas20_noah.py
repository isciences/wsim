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
import sys
import unittest

from wsim_workflow.workflow import generate_steps, find_duplicate_targets
from wsim_workflow.workflow import unbuildable_targets

from config_gldas20_noah import GLDAS20_NoahConfig

def strip_existing_dependencies(step):
    step.dependencies = [dep for dep in step.dependencies if not os.path.exists(dep)]

class TestGLDAS20_NoahConfig(unittest.TestCase):
    source = os.path.expanduser('~/wsim/source/GLDAS20') # Can only run some tests if the inputs actually exist
    derived = '/tmp/derived'

    def fail_on_duplicate_targets(self, steps):
        duplicate_targets = find_duplicate_targets(steps)

        if duplicate_targets:
            for target in duplicate_targets:
                print("Duplicate target:", target, file=sys.stderr)
            self.fail('Duplicate targets found')

    @unittest.skipUnless(os.path.exists(source), "Can only run test if inputs exist")
    def test_all_steps_buildable(self):
        config = GLDAS20_NoahConfig(self.source, self.derived)

        yearmon = '{year:04d}{month:02d}'.format(year=config.historical_years()[-1], month=4)

        steps = generate_steps(config, start=yearmon, stop=yearmon, no_spinup=False, forecasts='latest',
                               run_electric_power=False)

        # The GLDAS20_Noah config doesn't include steps for fetching the data, so we need
        # to remove dependencies on these files for the purpose of checking buildable
        # targets.
        for step in steps:
            strip_existing_dependencies(step)

        unbuildable = unbuildable_targets(steps)

        if unbuildable:
            for step in unbuildable:
                for t in step.targets:
                    print("Don't know how to build", t, "(depends on", ",".join(step.dependencies), ")", file=sys.stderr)
                self.fail('Unbuildable targets found')

    def test_no_duplicate_targets(self):
        config = GLDAS20_NoahConfig(self.source, self.derived)

        # Shouldn't get duplicate steps within fit period
        self.fail_on_duplicate_targets(generate_steps(config, start='196404', stop='196404', no_spinup=False, forecasts='latest', run_electric_power=False))

        # Or after fit period, but still within historical period
        self.fail_on_duplicate_targets(generate_steps(config, start='201004', stop='201004', no_spinup=False, forecasts='latest', run_electric_power=False))
