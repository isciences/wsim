#!/usr/bin/env python3

# Copyright (c) 2018-2019 ISciences, LLC.
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
import datetime
import os
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

    try:
        with open(os.path.join(output_dir, fname), 'wb') as outfile:
            sys.stdout.write(url)
            res = urlopen(url)
            for chunk in iter(lambda : res.read(1024 * 256), b''):
                sys.stdout.write('.')
                sys.stdout.flush()
                outfile.write(chunk)
    except:
        os.remove(os.path.join(output_dir, fname))
        raise
    finally:
        sys.stdout.write('\n')


def main(raw_args):
    args = parse_args(raw_args)

    year = int(args.timestamp[0:4])
    month = int(args.timestamp[4:6])
    day = int(args.timestamp[6:8])
    hour = int(args.timestamp[8:10])

    hindcast = year <= 2009

    if hindcast:
        grib_pattern = "flxf{TIMESTAMP}.01.{TARGET}.avrg.grb2"
    else:
        grib_pattern = "flxf.01.{TIMESTAMP}.{TARGET}.avrg.grib.grb2"

    gribfile = grib_pattern.format(TIMESTAMP=args.timestamp, TARGET=args.target)

    if hindcast:
        url_patterns = [
            'https://nomads.ncdc.noaa.gov/modeldata/cmd_mm_9mon/{YEAR:04d}/{YEAR:04d}{MONTH:02d}/{YEAR:04d}{MONTH:02d}{DAY:02d}/{GRIBFILE}'
        ]
    else:
        start_of_rolling_archive = datetime.datetime.now() - datetime.timedelta(days=8) # should have 7 days but could have more or less
        timestamp_datetime = datetime.datetime(year, month, day, hour)

        if timestamp_datetime > datetime.datetime.utcnow():
            print("Can't download forecast with timestamp in the future.", file=sys.stderr)
            sys.exit(1)

        url_patterns = [
            'ftp://nomads.ncdc.noaa.gov/modeldata/cfsv2_forecast_mm_9mon/{YEAR:04d}/{YEAR:04d}{MONTH:02d}/{YEAR:04d}{MONTH:02d}{DAY:02d}/{TIMESTAMP}/{GRIBFILE}',
            'https://nomads.ncdc.noaa.gov/modeldata/cfsv2_forecast_mm_9mon/{YEAR:04d}/{YEAR:04d}{MONTH:02d}/{YEAR:04d}{MONTH:02d}{DAY:02d}/{TIMESTAMP}/{GRIBFILE}',
        ]

        rolling_url_pattern = 'https://nomads.ncep.noaa.gov/pub/data/nccf/com/cfs/prod/cfs/cfs.{YEAR:04d}{MONTH:02d}{DAY:02d}/{HOUR:02d}/monthly_grib_01/{GRIBFILE}'

        if timestamp_datetime > start_of_rolling_archive:
            print("Attempting rolling archive URL first")
            url_patterns.insert(0, rolling_url_pattern)
        else:
            print("Attempting long-term archive URL first")
            url_patterns.append(rolling_url_pattern)

    for url_pattern in url_patterns:
        url = url_pattern.format(YEAR=year,
                                 MONTH=month,
                                 DAY=day,
                                 HOUR=hour,
                                 TIMESTAMP=args.timestamp,
                                 GRIBFILE=gribfile)

        try:
            download(url, args.output_dir)
            sys.exit(0)
        except Exception as e:
            print("Failed to download from " + url + " with error: ", file=sys.stderr)
            print(e, file=sys.stderr)
    sys.exit(1)


if __name__ == "__main__":
    main(sys.argv[1:])
