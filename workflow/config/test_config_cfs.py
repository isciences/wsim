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
import warnings

from wsim_workflow import dates
from wsim_workflow import spinup
from wsim_workflow.workflow import generate_steps, find_duplicate_targets, write_makefile, unbuildable_targets

from config_cfs import CFSConfig


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
        member_dates = set(m[:8] for m in members)

        self.assertEqual(28, len(members))
        self.assertSetEqual(member_dates, {'20170125', '20170126', '20170127', '20170128', '20170129', '20170130', '20170131'})

    def test_history_length(self):
        config = CFSConfig(self.source, self.derived)

        self.assertEqual(60, len(config.result_fit_years()))

    def test_all_steps_buildable(self):
        config = CFSConfig(self.source, self.derived)

        # Find the timestep that's one month beyond our historical period
        yearmon_after_historical = '{year:04d}{month:02d}'.format(year=1 + config.historical_years()[-1], month=1)
        yearmon_within_historical = '{year:04d}{month:02d}'.format(year=config.historical_years()[-1], month=4)

        for yearmon in (yearmon_within_historical, yearmon_after_historical):
            steps = generate_steps(config, start=yearmon, stop=yearmon, no_spinup=False, forecasts='latest', run_electric_power=True, run_agriculture=True)

            print('Number of steps:', len([step for step in steps if step.commands]))

            targets = set()

            commands = set()
            for step in steps:
                for cmd in step.commands:
                    commands.add(' '.join(cmd))
                targets |= step.targets
            print('Number of commands:', len(commands))
            print('Number of targets:', len(targets))

            unbuildable = unbuildable_targets(steps)

            if unbuildable:
                for step in unbuildable:
                    for t in step.targets:
                        print("Don't know how to build", t, "(depends on", ",".join(sorted(step.dependencies)), ")", file=sys.stderr)
                self.fail('Unbuildable targets found')

    def test_complex_rules(self):
        config = CFSConfig(self.source, self.derived)
        warnings.simplefilter("always")

        yearmon = '{year:04d}{month:02d}'.format(year=config.historical_years()[-1], month=1)

        steps = generate_steps(config, start=yearmon, stop=yearmon, no_spinup=False, forecasts='latest', run_electric_power=True, run_agriculture=True)

        targets_threshold = 2
        dependencies_threshold = 100

        for step in steps:
            if len(step.targets) > targets_threshold:
                warnings.warn("Step with > {} targets: {}".format(targets_threshold, step.comment or "unnamed"))
                print(step.targets)
            if len(step.dependencies) > dependencies_threshold:
                warnings.warn("Step with > {} dependencies: {}".format(dependencies_threshold, step.comment or "unnamed"))
                print(step.targets)

    def test_no_duplicate_targets(self):
        config = CFSConfig(self.source, self.derived)

        # Shouldn't get duplicate steps within fit period
        self.fail_on_duplicate_targets(generate_steps(config, start='196404', stop='196404', no_spinup=False, forecasts='latest', run_electric_power=True, run_agriculture=True))

        # Or after fit period, but still within historical period
        self.fail_on_duplicate_targets(generate_steps(config, start='201504', stop='201504', no_spinup=False, forecasts='latest', run_electric_power=True, run_agriculture=True))

        # Or after historical period
        self.fail_on_duplicate_targets(generate_steps(config, start='201801', stop='201801', no_spinup=False, forecasts='latest', run_electric_power=True, run_agriculture=True))

    def test_var_fitting_years(self):
        # Check that, when fitting time-integrated variables, we correctly truncate the historical range to
        # account for the integration period
        config = CFSConfig(self.source, self.derived)

        fit_step = spinup.fit_var(config, param='RO_mm', stat='ave', window=24, month=6)[0]
        input_results = get_arg(fit_step.commands[0], '--input').split('/')[-1]

        start_year = list(config.result_fit_years())[0] + 2
        stop_year = list(config.result_fit_years())[-1]

        self.assertTupleEqual(
            (dates.format_yearmon(start_year, 6), dates.format_yearmon(stop_year, 6), '12'),
            re.search('\[(\d+):(\d+):(\d+)\]', input_results).groups()
        )

    def test_adjusted_composites(self):
        # Adjusted composites are tricky, because we can't produce them during result_fit_years.

        config = CFSConfig(self.source, self.derived)

        # Get a timestep that is within the historical period but not the result fit period
        yearmon = next(iter(set(config.historical_yearmons()) ^ set(config.result_fit_yearmons())))

        expected_filename = config.workspace().composite_summary_adjusted(yearmon=yearmon, window=1)

        steps = generate_steps(config, start=yearmon, stop=yearmon, no_spinup=False, forecasts='latest', run_electric_power=True, run_agriculture=True)

        for step in steps:
            if expected_filename in step.targets:
                return

        self.fail()

    def test_expected_outputs_created(self):
        config = CFSConfig(self.source, self.derived)
        yearmon = '201901'
        target = '201904'
        member = config.forecast_ensemble_members(yearmon)[0]

        steps = generate_steps(config, start=yearmon, stop=yearmon, no_spinup=True, forecasts='latest', run_electric_power=False, run_agriculture=False)

        ws = config.workspace()

        def assertBuilt(fname):
            self.assertIsNotNone(step_for_target(steps, fname))

        # forcing
        assertBuilt(ws.forcing(yearmon=yearmon))
        assertBuilt(ws.forcing_summary(yearmon=yearmon, target=target))

        # results
        assertBuilt(ws.results(yearmon=yearmon, window=1))
        assertBuilt(ws.results(yearmon=yearmon, target=target, summary=True, window=1))
        assertBuilt(ws.results(yearmon=yearmon, target=target, member=member, window=1))

        # integrated results
        assertBuilt(ws.results(yearmon=yearmon, window=3))
        assertBuilt(ws.results(yearmon=yearmon, target=target, summary=True, window=3))
        assertBuilt(ws.results(yearmon=yearmon, target=target, member=member, window=3))

        # return periods
        assertBuilt(ws.return_period(yearmon=yearmon, window=1))
        assertBuilt(ws.return_period_summary(yearmon=yearmon, target=target, window=1))
        assertBuilt(ws.return_period(yearmon=yearmon, target=target, member=member, window=1))

        # integrated return periods
        assertBuilt(ws.return_period(yearmon=yearmon, window=3))
        assertBuilt(ws.return_period_summary(yearmon=yearmon, target=target, window=3))
        assertBuilt(ws.return_period(yearmon=yearmon, target=target, member=member, window=3))

        # composites
        assertBuilt(ws.composite_summary(yearmon=yearmon, window=1))
        assertBuilt(ws.composite_summary(yearmon=yearmon, target=target, window=1))

        # integrated composites
        assertBuilt(ws.composite_summary(yearmon=yearmon, window=3))
        assertBuilt(ws.composite_summary(yearmon=yearmon, target=target, window=3))

    def test_rp_calculated_for_all_necessary_vars(self):
        config = CFSConfig(self.source, self.derived)
        yearmon = '201901'
        target = '201904'
        member = config.forecast_ensemble_members(yearmon)[0]

        steps = generate_steps(config, start=yearmon, stop=yearmon, no_spinup=True, forecasts='latest', run_electric_power=False, run_agriculture=False)

        ws = config.workspace()

        # 1-month observed rp
        rp_step = step_for_target(steps, ws.return_period(yearmon=yearmon, window=1))
        for v in config.lsm_rp_vars() + config.forcing_rp_vars():
            self.assertIn(ws.fit_obs(var=v, window=1, month=dates.parse_yearmon(yearmon)[1]),
                          rp_step.dependencies)

        # 1-month forecast rp
        rp_step = step_for_target(steps, ws.return_period(yearmon=yearmon, target=target, member=member, window=1))
        for v in config.lsm_rp_vars() + config.forcing_rp_vars():
            self.assertIn(ws.fit_obs(var=v, window=1, month=dates.parse_yearmon(target)[1]),
                          rp_step.dependencies)

        # 3-month observed rp
        rp_step = step_for_target(steps, ws.return_period(yearmon=yearmon, window=3))
        for v, stats in config.lsm_integrated_vars().items():
            for stat in stats:
                self.assertIn(ws.fit_obs(var=v, window=3, stat=stat, month=dates.parse_yearmon(yearmon)[1]),
                              rp_step.dependencies)

        ## 3-month forecast rp
        rp_step = step_for_target(steps, ws.return_period(yearmon=yearmon, target=target, member=member, window=3))
        for v in config.lsm_integrated_var_names():
            self.assertTrue(ws.fit_obs(var=v, window=3, month=dates.parse_yearmon(target)[1])
                            in rp_step.dependencies)


    @unittest.skip
    def test_makefile_readable(self):
        import wsim_workflow.output.gnu_make
        config = CFSConfig(self.source, self.derived)

        bindir = os.path.realpath(os.path.join(os.path.dirname(__file__), os.pardir))

        steps = generate_steps(config, start='201701', stop='201701', no_spinup=False, forecasts='latest', run_electric_power=True, run_agriculture=True)

        filename = tempfile.mkstemp()[-1]

        write_makefile(wsim_workflow.output.gnu_make, filename, steps, bindir)

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


def step_for_target(steps, target):
    for step in steps:
        if target in step.targets:
            return step


