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

import os
from typing import List

from .. import dates
from ..step import Step

SUBDIR = 'ERA5'


def filename(source: str, duration: str, yearmon: str) -> str:
    assert duration in ('month', 'hour')
    return os.path.join(source, SUBDIR, duration, 'era5_{}_{}.nc'.format(duration, yearmon))


def land_mask_filename(source: str, min_fraction_land) -> str:
    return os.path.join(source, SUBDIR, 'land_mask_{}.nc'.format(min_fraction_land*100))


def calculate_land_mask(source, min_fraction_land: float) -> List[Step]:
    land_fraction_fname = os.path.join(source, SUBDIR, 'land_fraction.nc')

    return download(land_fraction_fname, 'month', '202001', ['land_sea_mask']) + \
        [
            Step(
                targets=land_mask_filename(source, min_fraction_land),
                dependencies=land_fraction_fname,
                commands=[
                    [
                        os.path.join('{BINDIR}', 'utils', 'era5', 'create_era5_mask.R'),
                        '--input', land_fraction_fname,
                        '--output', land_mask_filename(source, min_fraction_land),
                        '--threshold', str(min_fraction_land)
                    ]
                ]
            )
        ]

def download(output_filename: str, duration: str, yearmon: str, variables: List[str]) -> List[Step]:
    year, month = dates.parse_yearmon(yearmon)

    return [
        Step(
            targets=output_filename,
            dependencies=[],
            commands=[
                [
                    os.path.join('{BINDIR}', 'utils', 'era5', 'download_era5.py'),
                    '--year', str(year),
                    '--month', str(month),
                    '--timestep', duration,
                    '--outfile', output_filename
                ] + variables
            ]
        )
    ]


def calc_wetdays(input_filename: str, output_filename: str, threshold_mm: float) -> List[Step]:
    return [
        Step(
            targets=output_filename,
            dependencies=[input_filename],
            commands=[
                [
                    os.path.join('{BINDIR}', 'utils', 'era5', 'calc_era5_wetdays.R'),
                    '--input', input_filename,
                    '--output', output_filename,
                    '--threshold', str(threshold_mm),
                ]
            ]
        )
    ]
