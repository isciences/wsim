#!/usr/bin/env python3

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

    # There is some inconsistency in how daily precipitation files are named
    # from year to year. Because we want to be able to mirror this data source
    # using wget, we don't correct the inconsistencies in our local copy.
    if year < 2006:
        ext = ".gz"
    elif year < 2007:
        ext = "RT.gz"
    elif year < 2009:
        ext = ".RT.gz"
    else:
        ext = ".RT"

    input_files = os.path.join(args.input_dir,
                               str(year),
                               'PRCP_CU_GAUGE_V1.0GLB_0.50deg.lnx.[{YEARMON}01:{YEARMON}{DAYS_IN_MONTH:02d}]{EXT}::1@[x-1]->Pr'.format(YEARMON=args.yearmon,
                                                                                                                                     DAYS_IN_MONTH=calendar.monthrange(year, month)[1],
                                                                                                                                     EXT=ext))
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
