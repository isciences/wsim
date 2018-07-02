#!/usr/bin/env python3

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

from . import dates
from . import monthly
from . import spinup

from .step import Step

def find_duplicate_targets(steps):
    targets = set()
    duplicates = set()

    for step in steps:
        for target in step.targets:
            if target in targets:
                duplicates.add(target)
            targets.add(target)

    return sorted(list(duplicates))

def generate_steps(config, start, stop, no_spinup, forecasts):
    steps = []

    steps += config.global_prep()

    meta_steps = { name : Step.create_meta(name) for name in (
        'all_fits',
        'all_composites',
        'all_monthly_composites',
        'all_adjusted_composites',
        'all_adjusted_monthly_composites',
        'forcing_summaries',
        'results_summaries'
    )}

    if config.should_run_spinup() and not no_spinup:
        steps += spinup.spinup(config, meta_steps)

    for i, yearmon in enumerate(reversed(list(dates.get_yearmons(start, stop)))):
        steps += monthly.monthly_observed(config, yearmon, meta_steps)

        if forecasts == 'all' or (forecasts == 'latest' and i == 0):
            steps += monthly.monthly_forecast(config, yearmon, meta_steps)

    steps += meta_steps.values()

    return steps


def write_makefile(module, filename, steps, bindir):
    os.makedirs(os.path.dirname(filename), exist_ok=True)

    with open(filename, 'w') as outfile:
        outfile.write(module.header())
        outfile.write(2*'\n')

        # Reverse the steps so that spinup stuff is at the end. This is just to improve readability
        # if the user wants to manually inspect the Makefile
        for step in reversed(steps):
            outfile.write(module.write_step(step, {'BINDIR' : bindir}))
            outfile.write('\n')

        print("Done")


def unbuildable_targets(steps):
    """
    Walk the dependency tree of a number of steps and make sure that all steps are buildable
    (i.e., the step either has known dependencies or depends on a step that, in turn, has no
    dependencies)

    Return a list of steps that cannot be built.
    """

    builder_of = {}

    for step in steps:
        step.depth = None
        for t in step.targets:
            builder_of[t] = step

    def step_depth(step):
        if step.depth is not None:
            return step.depth

        if not step.dependencies:
            return 0

        else:
            return 1 + max(step_depth(builder_of[d]) if d in builder_of else float('inf') for d in step.dependencies)

    for step in steps:
        step.depth = step_depth(step)

    max_depth = max(step_depth(step) for step in steps)

    print('Maximum dependency tree depth:', max_depth)

    return [step for step in steps if step.depth == float('inf')]
