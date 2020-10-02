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

from __future__ import print_function  # Avoid bombing in Python 2 before we even hit our version check

import sys

if sys.version_info.major < 3:
    print("Must use Python 3")
    sys.exit(1)

import os
import argparse

from wsim_workflow import workflow
from wsim_workflow import dates

import importlib
import importlib.util
import sys


def load_module(module):
    return importlib.import_module('wsim_workflow.output.{}'.format(module))


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
    parser.add_argument('--noelectric',
                        help='Do not write steps for electric power assessment',
                        action='store_true')
    parser.add_argument('--noagriculture',
                        help='Do not write steps for agriculture assessment',
                        action='store_true')
    parser.add_argument('--module',
                        help="Name of output module",
                        default='gnu_make')
    parser.add_argument('--makefile',
                        help='Name of generated makefile',
                        required=False)
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
    parser.add_argument('--step',
                        help='Generate steps for every N months between start and stop [default: 1]',
                        default=1,
                        type=int)
    parser.add_argument('--forecast-lag-hours',
                        type=int,
                        help="Only attempt to download forecasts issued within the specified number of hours")

    parsed = parser.parse_args(args)

    if parsed.stop is None:
        parsed.stop = parsed.start

    if not dates.is_yearmon(parsed.start):
        sys.exit('Start date {} is not in YYYYMM format.'.format(parsed.start))

    if not dates.is_yearmon(parsed.stop):
        sys.exit('Stop date {} is not in YYYYMM format.'.format(parsed.stop))

    if parsed.forecasts not in ('all', 'none', 'latest'):
        sys.exit('--forecasts flag must be one of: all, none, latest')

    return parsed


def main(raw_args):
    args = parse_args(raw_args)

    output_module = load_module(args.module)
    output_filename = args.makefile or output_module.DEFAULT_FILENAME

    config = workflow.load_config(args.config, args.source, args.workspace)

    steps = workflow.generate_steps(config,
                                    start=args.start,
                                    stop=args.stop,
                                    step=args.step,
                                    no_spinup=args.nospinup,
                                    forecasts=args.forecasts,
                                    run_electric_power=not args.noelectric,
                                    run_agriculture=not args.noagriculture,
                                    forecast_lag_hours=args.forecast_lag_hours)

    duplicate_targets = workflow.find_duplicate_targets(steps)
    if duplicate_targets:
        for target in duplicate_targets[:100]:
            print("Duplicate target encountered:", target, file=sys.stderr)

    workflow_file = os.path.join(args.workspace, output_filename)
    print('Writing {} steps to {} using module: {}'.format(len(steps), workflow_file, args.module))
    workflow.write_makefile(output_module, workflow_file, steps, args.bindir)


if __name__ == "__main__":
    main(sys.argv[1:])
