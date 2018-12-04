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
import tempfile
from typing import List

from ..commands import move
from ..step import Step


def admin_boundaries(source_dir: str, levels: List[int]) -> List[Step]:
    for level in levels:
        assert 0 <= level <= 5

    dirname = os.path.join(source_dir, 'GADM')
    url = 'https://biogeo.ucdavis.edu/data/gadm3.6/gadm36_levels_shp.zip'
    zip_path = os.path.join(dirname, url.split('/')[-1])

    # ogr2ogr seems to have trouble writing from one gpkg to another on the same
    # cifs share. Work around this by writing to a local temp folder and then
    # moving.
    steps = [
        Step(
            targets=zip_path,
            dependencies=[],
            commands=[
                ['wget', '--directory-prefix', dirname, url]
            ]
        ),
    ]

    # Read each layer and write to its own GeoPackage. Although we could just download
    # GeoPackages from GADM, it's better to create our own so that ogr2ogr will add
    # a numeric FID column for us. And writing as a shapefile takes forever, because
    # ogr2ogr has to switch from OGR to ESRI ring rules.
    for level in levels:
        temp_gpkg = tempfile.mktemp(suffix='.gpkg')
        gpkg_path = os.path.join(dirname, 'gadm36_level_{}.gpkg'.format(level))

        steps += [
            Step(
                targets=temp_gpkg,
                dependencies=zip_path,
                commands=[
                    [
                        'ogr2ogr',
                        temp_gpkg,
                        '-nlt', 'PROMOTE_TO_MULTI',
                        '/vsizip/{}'.format(zip_path),
                        '-sql', '"SELECT fid AS GID, * FROM gadm36_{}"'.format(level)  # input layer name
                    ]
                ]
            ),

            move(from_path=temp_gpkg, to_path=gpkg_path)
        ]

    return steps
