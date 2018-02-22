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

from __future__ import print_function # Avoid bombing in Python 2 before we even hit our version check

import sys

if sys.version_info.major < 3:
    print("Must use Python 3")
    sys.exit(1)

import os
import monthly
import spinup
import dates
import argparse

from step import Step

def load_config(path, source, derived):
    from importlib.machinery import SourceFileLoader
    return SourceFileLoader("config", path).load_module().config(source, derived)

def parse_args(args):
    parser = argparse.ArgumentParser('Generate a Makefile for WSIM data processing')

    parser.add_argument('--bindir',
                        help='Path to WSIM executables',
                        required=False,
                        default='/wsim')
    parser.add_argument('--config',
                        help='Python file describing run configuration',
                        required=True)
    parser.add_argument('--forecasts',
                        default="latest",
                        help='Write steps for forecasts [all, none, latest] (default: latest)')
    parser.add_argument('--nospinup',
                        help='Skip model spin-up steps',
                        action='store_true')
    parser.add_argument('--makefile',
                        help='Name of generated makefile',
                        required=False,
                        default='Makefile')
    parser.add_argument('--source',
                        help='Root directory for source data files',
                        required=True)
    parser.add_argument('--workspace',
                        help='Root directory workspace (derived files)',
                        required=True)
    parser.add_argument('--start',
                        help='Start date in YYYYMM format',
                        required=True)
    parser.add_argument('--stop',
                        help='End date in YYYYMM format',
                        required=False)

    parsed = parser.parse_args(args)

    if parsed.stop is None:
        parsed.stop = parsed.start

    if parsed.forecasts not in ('all', 'none', 'latest'):
        sys.exit('--forecasts flag must be one of: all, none, latest')

    return parsed

def find_duplicate_targets(steps):
    targets = set()
    duplicates = set()

    for step in steps:
        for target in step.targets:
            if target in targets:
                duplicates.add(target)
            targets.add(target)

    return sorted(list(duplicates))

def write_makefile(filename, steps, bindir):
    os.makedirs(os.path.dirname(filename), exist_ok=True)

    with open(filename, 'w') as outfile:
        outfile.write('.DELETE_ON_ERROR:\n') # Delete partially-created files on error or cancel
        outfile.write('.SECONDARY:\n')       # Prevent removal of targets considered "intermediate"
        outfile.write('.SUFFIXES:\n')        # Disable implicit rules
        outfile.write('\n')

        # Reverse the steps so that spinup stuff is at the end. This is just to improve readability
        # if the user wants to manually inspect the Makefile
        for step in reversed(steps):
            outfile.write(step.get_text({'BINDIR' : bindir}))
            outfile.write('\n')

        print("Done")

def main(raw_args):
    args = parse_args(raw_args)

    config = load_config(args.config, args.source, args.workspace)

    steps = []

    steps += config.global_prep()

    meta_steps = dict(
        all_monthly_composites=[],
        all_composites=[],
    )

    if config.should_run_spinup() and not args.nospinup:
        steps += spinup.spinup(config, meta_steps)

    for i, yearmon in enumerate(reversed(list(dates.get_yearmons(args.start, args.stop)))):
        steps += monthly.monthly_observed(config, yearmon, meta_steps)

        if args.forecasts == 'all' or (args.forecasts == 'latest' and i == 0):
            steps += monthly.monthly_forecast(config, yearmon, meta_steps)

    duplicate_targets = find_duplicate_targets(steps)
    if duplicate_targets:
        for target in duplicate_targets[:100]:
            print("Duplicate target encountered:", target, file=sys.stderr)

    for meta_step, deps in meta_steps.items():
        steps.append(Step(targets=meta_step, dependencies=deps, commands=[]))

    write_makefile(os.path.join(args.workspace, args.makefile), steps, args.bindir)

if __name__ == "__main__":
    main(sys.argv[1:])
