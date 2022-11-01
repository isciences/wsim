#!/usr/bin/env python3

# Copyright (c) 2021 ISciences, LLC.
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

import argparse
import cdsapi
import os
import shutil
import sys
import subprocess
import tempfile

from typing import List


def get_dataset(duration: str, year: int) -> dict:
    if duration == 'month':
        if year >= 1979:
            return {
                'dataset_short_name': 'reanalysis-era5-single-levels-monthly-means',
                'product_type':  'monthly_averaged_reanalysis'
            }
        else:
            return {
                'dataset_short_name': 'reanalysis-era5-single-levels-monthly-means-preliminary-back-extension',
                'product_type': 'reanalysis-monthly-means-of-daily-means'
            }
    if duration == 'hour':
        if year >= 1979:
            return {
                'dataset_short_name': 'reanalysis-era5-single-levels',
                'product_type': 'reanalysis'
            }
        else:
            return {
                'dataset_short_name': 'reanalysis-era5-single-levels-preliminary-back-extension',
                'product_type': 'reanalysis'
            }


def get_era5(outfile: str, duration: str, variables: List[str], year: int, month: int) -> None:
    # format options are GRIB and netCDF. Files are the same size.
    # GDAL throws a bunch of warnings when reading the GRIB file
    # but the values seem to come in ok. Might as well do netCDF
    # so we get names for the bands.
    dataset = get_dataset(duration, year)

    request = {
        'product_type': dataset['product_type'],
        'variable': variables,
        'year':  '{:04d}'.format(year),
        'month': '{:02d}'.format(month),
        'format': 'netcdf'
    }

    if duration == 'month':
        request['time'] = '00:00'

    if duration == 'hour':
        request.update({
            'day': ['{:02d}'.format(d) for d in range(1, 32)],
            'time': ['{:02d}:00'.format(h) for h in range(0, 24)],
        })

    c = cdsapi.Client()
    c.retrieve(dataset['dataset_short_name'],
               request,
               outfile)


def parse_args(args):
    parser = argparse.ArgumentParser('Download ERA5 temperature and precipitation')
    
    parser.add_argument('--year',
                        help='Data year (>= 1950)',
                        type=int,
                        required=True)
    parser.add_argument('--month',
                        help='Data month',
                        type=int,
                        required=True)
    parser.add_argument('--timestep',
                        help='Data time frequency',
                        choices=['month', 'hour'],
                        required=True)
    parser.add_argument('--outfile',
                        help='Output filename (.nc)',
                        required=True)
    parser.add_argument('var',
                        type=str,
                        nargs='+',
                        help='Variable(s) to download')

    parsed = parser.parse_args(args)

    return parsed


def main(raw_args):
    args = parse_args(raw_args)

    dotrc = os.environ.get("CDSAPI_RC", os.path.expanduser("~/.cdsapirc"))
    if not os.path.exists(dotrc):
        print('{} requires a configuration file to be stored at {} or an alternate location'.format(os.path.basename(__file__), '~/.cdsapirc', file=sys.stderr))
        print('specified by the CDSAPI_RC environment variable. Instructions for creating the file can be found at', file=sys.stderr)
        print('https://cds.climate.copernicus.eu/api-how-to#install-the-cds-api-key', file=sys.stderr)
        sys.exit(1)

    fh, fname = tempfile.mkstemp()
    os.close(fh)
    get_era5(fname, args.timestep, args.var, args.year, args.month)

    if args.timestep == 'month' and 'total_precipitation' in args.var:
        # ERA5 monthly average precipitation netCDFs have a unit of "m" but the stored values are actually "m/day"
        subprocess.run(['ncatted',
                        '-a', 'units,tp,m,c,m/day',
                        fname
        ])

    subprocess.run(['nccopy',
                    '-7',   # netCDF 4 classic
                    '-d1',  # level 1 deflate,
                    '-s',   # shuffle bits for better compression
                    '-c', 'time/1,latitude/721,longitude/1440',  # set chunk size for better compression and optimal access by time
                    fname,
                    args.outfile],
                   check=True)

    os.remove(fname)

    # TODO populate standard_name attribute either here or in workflow invocation of wsim_merge


if __name__ == "__main__":
    main(sys.argv[1:])