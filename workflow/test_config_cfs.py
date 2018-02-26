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
import subprocess
import sys
import unittest

from config_cfs import CFSConfig
from makemake import generate_steps, find_duplicate_targets, write_makefile

class TestCFSConfig(unittest.TestCase):
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

    def test_all_steps_buildable(self):
        config = CFSConfig(self.source, self.derived)

        steps = generate_steps(config, '201701', '201701', False, 'latest')

        unbuildable = unbuildable_targets(steps)

        if unbuildable:
            for step in unbuildable:
                for t in step.targets:
                    print("Don't know how to build", t, "(depends on", ",".join(step.dependencies), ")", file=sys.stderr)
            self.fail('Unbuildable targets found')

    def test_no_duplicate_steps(self):
        config = CFSConfig(self.source, self.derived)

        steps = generate_steps(config, '201701', '201701', False, 'latest')

        self.assertEqual(0, len(find_duplicate_targets(steps)))

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

def unbuildable_targets(steps):
    """
    Walk the dependency tree of a number of steps and make sure that all steps are buildable
    (i.e., the step either has know dependencies or depends on a step that, in turn, has no
    dependencies)

    Return a list of steps that cannot be built.
    """
    known = set()

    remaining_to_validate = list(steps)
    stuck = False

    while not stuck:
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

    return remaining_to_validate


