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
import timeit
import tempfile
import re
import subprocess
import sys
import unittest

import dates
import spinup

from config_cfs import CFSConfig
from makemake import generate_steps, find_duplicate_targets, write_makefile

class TestCFSConfig(unittest.TestCase):
    source = '/tmp/source'
    derived = '/tmp/derived'

    def fail_on_duplicate_targets(self, steps):
        duplicate_targets = find_duplicate_targets(steps)

        if duplicate_targets:
            for target in duplicate_targets:
                print("Duplicate target:", target, file=sys.stderr)
            self.fail('Duplicate targets found')

    def test_ensemble_selection(self):
        config = CFSConfig(self.source, self.derived)

        members = config.forecast_ensemble_members('201701')
        dates = set(m[:8] for m in members)

        self.assertEqual(28, len(members))
        self.assertSetEqual(dates, {'20170125', '20170126', '20170127', '20170128', '20170129', '20170130', '20170131'})

    def test_history_length(self):
        config = CFSConfig(self.source, self.derived)

        self.assertEqual(60, len(config.result_fit_years()))

    def test_all_steps_buildable(self):
        config = CFSConfig(self.source, self.derived)

        # Find the timestep that's one month beyond our historical period
        yearmon = '{year:04d}{month:02d}'.format(year=config.historical_years()[-1], month=1)

        steps = generate_steps(config, yearmon, yearmon, False, 'latest')

        unbuildable = unbuildable_targets(steps)

        if unbuildable:
            for step in unbuildable:
                for t in step.targets:
                    print("Don't know how to build", t, "(depends on", ",".join(step.dependencies), ")", file=sys.stderr)
            self.fail('Unbuildable targets found')

    def test_no_duplicate_targets(self):
        config = CFSConfig(self.source, self.derived)

        # Shouldn't get duplicate steps within spinup period
        self.fail_on_duplicate_targets(generate_steps(config, '196404', '196404', False, 'latest'))

        # Or after it
        self.fail_on_duplicate_targets(generate_steps(config, '201801', '201801', False, 'latest'))

    def test_var_fitting_years(self):
        # Check that, when fitting time-integrated variables, we correctly truncate the historical range to
        # account for the integration period
        config = CFSConfig(self.source, self.derived)

        fit_step = spinup.fit_var(config, param='T', stat='ave', window=24, month=6)[0]
        input_results = get_arg(fit_step.commands[0], '--input').split('/')[-1]

        start_year = list(config.result_fit_years())[0] + 2
        stop_year = list(config.result_fit_years())[-1]

        self.assertTupleEqual(
            (dates.format_yearmon(start_year, 6), dates.format_yearmon(stop_year, 6), '12'),
            re.search('\[(\d+):(\d+):(\d+)\]', input_results).groups()
        )

        self.assertEqual(stop_year - start_year + 1,
                         len(fit_step.dependencies))

        self.assertTrue(str(start_year) in fit_step.dependencies[0])
        self.assertTrue(str(stop_year) in fit_step.dependencies[-1])

    @unittest.skip
    def test_makefile_readable(self):
        config = CFSConfig(self.source, self.derived)

        bindir = os.path.realpath(os.path.join(os.path.dirname(__file__), os.pardir))

        steps = generate_steps(config, '201701', '201701', False, 'latest')

        filename = tempfile.mkstemp()[-1]

        write_makefile(filename, steps, bindir)

        print('Wrote Makefile to', filename)

        start = timeit.default_timer()
        print('Checking Makefile...')
        return_code = subprocess.call(['make', '-f', filename, '-q', 'all_composites'])
        self.assertEqual(1, return_code) # Make returns 2 for invalid Makefile, 1 for "target needs to be built"
        end = timeit.default_timer()

        print('Makefile validated in', end-start)

def get_arg(command, arg):
    for i, token in enumerate(command):
        if command[i-1] == arg:
            return token

def unbuildable_targets(steps):
    """
    Walk the dependency tree of a number of steps and make sure that all steps are buildable
    (i.e., the step either has know dependencies or depends on a step that, in turn, has no
    dependencies)

    Return a list of steps that cannot be built.
    """
    known = set()

    max_depth = 0
    remaining_to_validate = list(steps)
    stuck = False

    while not stuck:
        max_depth += 1
        could_not_validate = []
        stuck = True

        for step in remaining_to_validate:
            deps = [step.dependencies] if type(step.dependencies) is str else step.dependencies
            targets = [step.targets] if type(step.targets) is str else step.targets

            if all(d in known for d in deps):
                stuck = False
                for t in targets:
                    known.add(t)
            else:
                could_not_validate.append(step)

        remaining_to_validate = could_not_validate

    print('Maximum dependency tree depth:', max_depth)

    return remaining_to_validate


