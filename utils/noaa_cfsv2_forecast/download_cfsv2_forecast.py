#!/usr/bin/env python3
from __future__ import print_function # Avoid bombing in Python 2 before we even hit our version check

import sys

if sys.version_info.major < 3:
    print("Must use Python 3")
    sys.exit(1)

import argparse
import datetime
import os
import shutil
from urllib.request import urlopen

def parse_args(args):
    parser = argparse.ArgumentParser('Download a CFSv2 forecast GRIB file')

    parser.add_argument('--timestamp',
                        help='Forecast timestamp in YYYYMMHH format',
                        required=False)
    parser.add_argument('--target',
                        help='Target year and month of forecast in YYYYMM format',
                        required=True)
    parser.add_argument('--output_dir',
                        help='Directory to which forecast should be written',
                        required=True)

    parsed = parser.parse_args(args)

    return parsed

def download(url, output_dir):
    fname = url.rsplit('/', 1)[-1]

    with open(os.path.join(output_dir, fname), 'wb') as outfile:
        sys.stdout.write(url)
        res = urlopen(url)
        for chunk in iter(lambda : res.read(1024 * 256), b''):
            sys.stdout.write('.')
            sys.stdout.flush()
            outfile.write(chunk)
        sys.stdout.write('\n')

def main(raw_args):
    args = parse_args(raw_args)

    year = int(args.timestamp[0:4])
    month = int(args.timestamp[4:6])
    day = int(args.timestamp[6:8])
    hour = int(args.timestamp[8:10])

    gribfile = "flxf.01.{TIMESTAMP}.{TARGET}.avrg.grib.grb2".format(TIMESTAMP=args.timestamp,
                                                                    TARGET=args.target)

    start_of_rolling_archive = datetime.datetime.now() - datetime.timedelta(days=7)
    timestamp_datetime = datetime.datetime(year, month, day, hour)

    if timestamp_datetime > start_of_rolling_archive:
        print("Using rolling archive URL")
        url_pattern = 'http://nomads.ncep.noaa.gov/pub/data/nccf/com/cfs/prod/cfs/cfs.{YEAR:04d}{MONTH:02d}{DAY:02d}/{HOUR:02d}/monthly_grib_01/{GRIBFILE}'
    else:
        print("Using long-term archive URL")
        url_pattern = 'https://nomads.ncdc.noaa.gov/modeldata/cfsv2_forecast_mm_9mon/{YEAR:04d}/{YEAR:02d}{MONTH:02d}/{YEAR:04d}{MONTH:02d}{DAY:02d}/{TIMESTAMP}/{GRIBFILE}'

    url = url_pattern.format(YEAR=year,
                             MONTH=month,
                             DAY=day,
                             HOUR=hour,
                             TIMESTAMP=args.timestamp,
                             GRIBFILE=gribfile)

    download(url, args.output_dir)

if __name__ == "__main__":
    main(sys.argv[1:])
