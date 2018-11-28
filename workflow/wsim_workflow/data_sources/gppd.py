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

from ..step import Step
from . import natural_earth


def power_plant_database(source_dir: str) -> List[Step]:
    dirname = os.path.join(source_dir, 'GPPD')
    url = 'https://raw.githubusercontent.com/wri/global-power-plant-database/master/output_database/global_power_plant_database.csv'  # noqa
    raw_gppd_path = os.path.join(dirname, url.split('/')[-1])

    url_once_through = 'https://s3.us-east-2.amazonaws.com/wsim-datasets/gppd_once_through_cooled.txt'
    once_through_path = os.path.join(dirname, url_once_through.split('/')[-1])

    output_path = os.path.join(dirname, 'gppd_inferred_cooling.nc')

    coastline_path = os.path.join(dirname, 'Natural_Earth', natural_earth.ne_filename(layer='coastline', resolution=10))

    return natural_earth.natural_earth(dirname, layer='coastline', resolution=10) + [
        # Download data
        Step(
            targets=raw_gppd_path,
            dependencies=[],
            commands=[
                ['wget', '--directory-prefix', dirname, url]
            ]
        ),

        # Download once-through cooled plants
        Step(
            targets=once_through_path,
            dependencies=[],
            commands=[
                ['wget', '--directory-prefix', dirname, url_once_through]
            ]
        ),

        # Set GPPD cooling types
        Step(
            targets=output_path,
            dependencies=[
                raw_gppd_path,
                once_through_path,
                coastline_path
            ],
            commands=[
                [
                    os.path.join('{BINDIR}', 'utils', 'global_power_plant_database', 'gppd_set_cooling.R'),
                    '--plants',       raw_gppd_path,
                    '--once_through', once_through_path,
                    '--coastline',    coastline_path,
                    '--output',       output_path
                ]
            ]
        )
    ]
