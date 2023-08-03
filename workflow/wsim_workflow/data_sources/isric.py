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

import os

from typing import List

from ..grids import Grid, GLOBAL_HALF_DEGREE
from ..step import Step


def global_tawc(*, source_dir: str, filename: str, grid: Grid) -> List[Step]:
    dirname = os.path.join(source_dir, 'ISRIC')
    url = 'https://files.isric.org/public/wise/wise_30sec_v1.zip'
    zip_path = os.path.join(dirname, url.split('/')[-1])
    raw_file = os.path.join(dirname, 'HW30s_FULL.txt')  # there are others, but might as well avoid a multi-target rule
    full_res_file = os.path.join(dirname, 'wise_30sec_v1_tawc.tif')

    steps = [
        # Download ISRIC data
        Step(
            targets=zip_path,
            dependencies=[],
            commands=[
                [
                    'wget',
                    '--directory-prefix', dirname,
                    '--user', 'public',
                    '--password', 'public',
                    url
                ]
            ]
        ),

        # Unzip ISRIC data
        Step(
            targets=raw_file,
            dependencies=zip_path,
            commands=[
                [
                    'unzip', '-j', zip_path, '-d', dirname,
                    'WISE30sec/Interchangeable_format/HW30s_FULL.txt',
                    'WISE30sec/Interchangeable_format/wise_30sec_v1.tif',
                    'WISE30sec/Interchangeable_format/wise_30sec_v1.tsv'
                ],
                ['touch', raw_file]
            ]
        ),

        # Create TAWC TIFF
        Step(
            targets=full_res_file,
            dependencies=raw_file,
            commands=[
                [
                    os.path.join('{BINDIR}', 'utils', 'isric_30sec_soils', 'extract_isric_tawc.R'),
                    '--data',      os.path.join(dirname, 'HW30s_FULL.txt'),
                    '--missing',   os.path.join('{BINDIR}', 'utils', 'isric_30sec_soils', 'example_tawc_defaults.csv'),
                    '--codes',     os.path.join(dirname, 'wise_30sec_v1.tsv'),
                    '--raster',    os.path.join(dirname, 'wise_30sec_v1.tif'),
                    '--output',    full_res_file,
                    '--max_depth', '1'
                ]
            ]
        )
    ]

    if grid == GLOBAL_HALF_DEGREE:
        steps.append(
            # Aggregate TAWC data
            Step(
                targets=filename,
                dependencies=full_res_file,
                commands=[
                    [
                        os.path.join('{BINDIR}', 'utils', 'aggregate.R'),
                        '--res', str(grid.dx()),
                        '--input', full_res_file,
                        '--output', filename
                    ]
                ]
            )
        )
    else:
        steps.append(
            Step(
                targets=filename,
                dependencies=full_res_file,
                commands=[
                    [
                        'gdalwarp',
                        '-tr', grid.gdal_tr(),
                        '-te', grid.gdal_te(),
                        '-r', 'average',
                        '-ot', 'Float32',
                        full_res_file,
                        filename
                    ]
                ]
            )
        )

    return steps
