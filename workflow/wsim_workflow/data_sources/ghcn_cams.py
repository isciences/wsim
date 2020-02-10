# Copyright (c) 2020 ISciences, LLC.
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

from typing import List

from ..step import Step

GHCN_CAMS_URL = 'ftp://ftp.cpc.ncep.noaa.gov/wd51yf/GHCN_CAMS/ghcn_cams_1948_cur.grb'
GHCN_CAMS_GRIB = 'ghcn_cams_1948_cur.grb'


def download_ghcn_cams(grib_file: str) -> List[Step]:
    return [
        Step(
            targets=grib_file,
            dependencies=[],
            commands=[
                [
                    'wget',
                    '-O', grib_file,
                    '--continue',
                    GHCN_CAMS_URL
                ]
            ]
        )
    ]


def extract_monthly_temperature(*, grib_file: str, output_filename: str, yearmon: str) -> List[Step]:
    assert yearmon >= '194801'

    return [
        Step(
            targets=output_filename,
            dependencies=grib_file,
            commands =[
                [
                    os.path.join('{BINDIR}',
                                 'utils',
                                 'ghcn_cams',
                                 'read_ghcn_cams.R'),
                    '--input', grib_file,
                    '--update_url', GHCN_CAMS_URL,
                    '--output', output_filename,
                    '--yearmon', yearmon,
                ]
            ]
        )
    ]
