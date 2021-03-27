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


def global_elevation(source_dir: str, filename: str, grid: Grid) -> List[Step]:
    dirname = os.path.join(source_dir, 'GMTED2010')
    url = 'http://edcintl.cr.usgs.gov/downloads/sciweb1/shared/topo/downloads/GMTED/Grid_ZipFiles/mn30_grd.zip'
    zip_path = os.path.join(dirname, url.split('/')[-1])
    raw_file = os.path.join(dirname, 'mn30_grd')

    steps = [
        # Download elevation data
        Step(
            targets=zip_path,
            dependencies=[],
            commands=[
                ['wget', '--directory-prefix', dirname, url]
            ]
        ),

        # Unzip elevation data
        Step(
            targets=raw_file,
            dependencies=zip_path,
            commands=[
                ['unzip', '-d', dirname, '-D', zip_path],
            ]
        )
    ]

    # Aggregate elevation data
    if grid == GLOBAL_HALF_DEGREE:
        steps.append(
            Step(
                targets=filename,
                dependencies=raw_file,
                commands=[
                    [
                        os.path.join('{BINDIR}', 'utils', 'aggregate.R'),
                        '--res', str(grid.dx()),
                        '--input', raw_file,
                        '--output', filename
                    ]
                ]
            )
        )
    else:
        steps.append(
            Step(
                targets=filename,
                dependencies=raw_file,
                commands=[
                    [
                        'gdalwarp',
                        '-tr', grid.gdal_tr(),
                        '-te', grid.gdal_te(),
                        '-r', 'average',
                        '-ot', 'Float32',
                        raw_file,
                        filename
                    ]
                ]
            )
        )

    return steps
