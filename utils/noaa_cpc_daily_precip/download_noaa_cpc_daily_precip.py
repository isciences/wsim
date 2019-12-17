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

import argparse
import calendar
import gzip
import os
import shutil
import sys
import tempfile

from urllib.request import urlopen

if sys.version_info.major < 3:
    print("Must use Python 3")
    sys.exit(1)


def parse_args(args):
    parser = argparse.ArgumentParser('Download a month of daily precipitation files')

    parser.add_argument('--yearmon',
                        help='Year and month to download in YYYYMM format',
                        required=True)
    parser.add_argument('--output_dir',
                        help='Directory to which forecast should be written',
                        required=True)

    parsed = parser.parse_args(args)

    return parsed


def get_folder_url(year):
    if year < 1979:
        raise Exception("Daily precipitation data not available before 1979")
    if year < 2006:
        return "ftp://ftp.cpc.ncep.noaa.gov/precip/CPC_UNI_PRCP/GAUGE_GLB/V1.0"
    else:
        return "ftp://ftp.cpc.ncep.noaa.gov/precip/CPC_UNI_PRCP/GAUGE_GLB/RT"


def get_extension(year):
    if year < 2006:
        return ".gz"
    elif year < 2007:
        return "RT.gz"
    elif year < 2009:
        return ".RT.gz"
    else:
        return ".RT"


def get_url(year, month, day):
    """
    Get the URL of a daily precipitation file
    """
    return '{ROOT}/{YEAR}/PRCP_CU_GAUGE_V1.0GLB_0.50deg.lnx.{YEAR:04d}{MONTH:02d}{DAY:02d}{EXT}'.format(
        ROOT=get_folder_url(year),
        YEAR=year,
        MONTH=month,
        DAY=day,
        EXT=get_extension(year)
    )


def get_standard_filename(year, month, day):
    """
    Get the "standardized" name of a daily precipitation file, i.e. the name under the
    scheme used for pre-2006 files.
    """
    return 'PRCP_CU_GAUGE_V1.0GLB_0.50deg.lnx.{YEAR:04d}{MONTH:02d}{DAY:02d}.gz'.format(YEAR=year, MONTH=month, DAY=day)


def download(url, output_file):
    """
    Downloads a file, optionally compressing it
    :param url: URL to download
    :param output_file: Path of downloaded file. If output_file ends in '.gz' and
                        URL does not, the file will be compressed on the fly.
    """

    needs_compression = output_file.endswith('.gz') and not url.endswith('.gz')

    opener = gzip.open if needs_compression else open

    # Write to a temp file so that we don't leave a partially
    # completed download if we're interrupted
    with tempfile.NamedTemporaryFile(dir='/tmp', delete=False) as tmpfile:
        temp_file_name = tmpfile.name

    with opener(temp_file_name, 'wb') as outfile:
        sys.stdout.write(url)
        res = urlopen(url)
        for chunk in iter(lambda: res.read(1024 * 256), b''):
            sys.stdout.write('.')
            sys.stdout.flush()
            outfile.write(chunk)
        sys.stdout.write('\n')

    shutil.move(temp_file_name, output_file)


def main(raw_args):
    args = parse_args(raw_args)

    year = int(args.yearmon[0:4])
    month = int(args.yearmon[4:6])
    output_dir = args.output_dir

    for day in range(1, 1+calendar.monthrange(year, month)[1]):
        output_file = os.path.join(output_dir,
                                   str(year),
                                   get_standard_filename(year, month, day))
        if os.path.exists(output_file):
            print('Skipping', output_file, '(already exists)')
        else:
            os.makedirs(os.path.dirname(output_file), exist_ok=True)
            download(get_url(year, month, day),
                     output_file)


if __name__ == "__main__":
    main(sys.argv[1:])
