#!/usr/bin/env python3

# Copyright (c) 2018-2020 ISciences, LLC.
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
import types
import importlib.machinery

from typing import List, Optional

from . import agriculture
from . import dates
from . import electric_power
from . import monthly
from . import spinup

from .config_base import ConfigBase
from .step import Step


def find_duplicate_targets(steps: List[Step]) -> List[Step]:
    targets = set()
    duplicates = set()

    for step in steps:
        for target in step.targets:
            if target in targets:
                duplicates.add(target)
            targets.add(target)

    return sorted(list(duplicates))


def get_meta_steps():
    return {name: Step.create_meta(name) for name in (
        'agriculture_assessment',
        'all_adjusted_composites',
        'all_adjusted_monthly_composites',
        'all_composites',
        'all_fits',
        'all_monthly_composites',
        'electric_power_assessment',
        'forcing_summaries',
        'prepare_forecasts',
        'results_summaries',
        'population_summaries'
    )}


def generate_steps(config: ConfigBase, *,
                   start: str,
                   stop: str,
                   step: Optional[int] = 1,
                   no_spinup: bool,
                   forecasts: str,
                   forecast_lag_hours: Optional[int] = None,
                   run_electric_power: bool,
                   run_agriculture: bool) -> List[Step]:
    steps = []

    steps += config.global_prep()

    meta_steps = get_meta_steps()

    if config.should_run_spinup() and not no_spinup:
        steps += spinup.spinup(config, meta_steps)
        if run_electric_power:
            steps += electric_power.spinup(config, meta_steps)
        if run_agriculture:
            steps += agriculture.spinup(config, meta_steps)


    for i, yearmon in enumerate(reversed(list(dates.get_yearmons(start, stop))[::step])):
        steps += monthly.monthly_observed(config, yearmon, meta_steps)

        if run_electric_power:
            steps += electric_power.monthly_observed(config, yearmon, meta_steps)
        if run_agriculture:
            steps += agriculture.monthly_observed(config, yearmon, meta_steps)

        if forecasts == 'all' or (forecasts == 'latest' and i == 0):
            steps += monthly.monthly_forecast(config, yearmon, meta_steps, forecast_lag_hours=forecast_lag_hours)

            if run_electric_power:
                steps += electric_power.monthly_forecast(config, yearmon, meta_steps)
            if run_agriculture:
                steps += agriculture.monthly_forecast(config, yearmon, meta_steps)

    steps += meta_steps.values()

    return steps


def write_makefile(module, filename: str, steps: List[Step], bindir: str) -> None:
    os.makedirs(os.path.dirname(filename), exist_ok=True)

    with open(filename, 'w') as outfile:
        outfile.write(module.header())
        outfile.write(2*'\n')

        # Reverse the steps so that spinup stuff is at the end. This is just to improve readability
        # if the user wants to manually inspect the Makefile
        for step in reversed(steps):
            outfile.write(module.write_step(step, {'BINDIR': bindir}))
            outfile.write('\n')

        print("Done")


def unbuildable_targets(steps) -> List[Step]:
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

    unbuildable = [step for step in steps if step.depth == float('inf')]

    if unbuildable:
        pass  # Convenient breakpoint
        print('xox')

    return unbuildable


def load_config(path: str, source: str, derived: str, config_options: dict) -> ConfigBase:
    config_dirname = os.path.split(os.path.dirname(path))[-1]
    config_name = os.path.splitext(os.path.basename(path))[0]

    spec = importlib.util.spec_from_file_location(f"{config_dirname}.{config_name}", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)

    return mod.config(source, derived, **config_options)
