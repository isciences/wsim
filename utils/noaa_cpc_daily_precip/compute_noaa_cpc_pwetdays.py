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

import argparse
import calendar
import os
import subprocess

def execute(cmd):
    p = subprocess.Popen(cmd,
                         stdout=subprocess.PIPE,
                         stderr=subprocess.STDOUT,
                         universal_newlines=True)

    for line in iter(p.stdout.readline, ''):
        print(line.strip())

    p.stdout.close()
    if p.wait():
        sys.exit(1)

def parse_args(args):
    parser = argparse.ArgumentParser('Compute pWetDays from NOAA/CPC daily precipitation data')

    parser.add_argument('--bindir',
                        help='Path to WSIM executables',
                        required=False,
                        default='/wsim')
    parser.add_argument('--yearmon',
                        help='Year and month to process (YYYYMM format)',
                        required=True)
    parser.add_argument('--input_dir',
                        help='Directory containing daily precipitation files',
                        required=True)
    parser.add_argument('--output_dir',
                        help='Director to which pWetDays should be written',
                        required=True)

    parsed = parser.parse_args(args)

    return parsed

def main(raw_args):
    args = parse_args(raw_args)

    year = int(args.yearmon[:4])
    month = int(args.yearmon[4:])

    if year < 1979:
        sys.exit("Daily precipitation data not available before 1979")

    input_files = os.path.join(args.input_dir,
                               str(year),
                               'PRCP_CU_GAUGE_V1.0GLB_0.50deg.lnx.[{YEARMON}01:{YEARMON}{DAYS_IN_MONTH:02d}].gz::1@[x-1]->Pr'.format(YEARMON=args.yearmon,
                                                                                                                                     DAYS_IN_MONTH=calendar.monthrange(year, month)[1]))
    os.makedirs(args.output_dir, exist_ok=True)
    output_file = os.path.join(args.output_dir, 'wetdays_{}.nc'.format(args.yearmon))

    execute([os.path.join(args.bindir, 'wsim_integrate.R'),
             '--input',  input_files,
             '--stat',   'fraction_defined_above_zero',
             '--output', output_file
             ])

    execute(['ncrename',
             '-O',
             '-vPr_fraction_defined_above_zero,pWetDays',
             output_file])

if __name__ == "__main__":
    main(sys.argv[1:])
