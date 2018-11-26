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

PHYSICAL = {
    'antarctic_ice_shelves_lines',
    'antarctic_ice_shelves_polys',
    'coastline',
    'elevation_points',
    'geography_regions_points',
    'geography_regions_polys',
    'glaciated_areas',
    'lakes',
    'lakes_europe',
    'lakes_historic',
    'lakes_north_america',
    'lakes_pluvial',
    'land',
    'marine_polys',
    'minor_islands',
    'ocean',
    'playas',
    'reefs',
    'rivers_lake_centerlines',
}

CULTURAL = {
    'admin_0_countries',
    'admin_1_states_provinces'
}


def check_resolution(resolution: int) -> None:
    if resolution not in (10, 50, 110):
        raise ValueError("Natural Earth data available at resolutions of 10, 50, and 110m")


def check_layer(layer: str) -> None:
    if layer not in PHYSICAL and layer not in CULTURAL:
        raise ValueError("Unsupported layer " + layer)


def ne_url(layer: str, resolution: int) -> str:
    category = 'physical' if layer in PHYSICAL else 'cultural'
    template_url = 'https://www.naturalearthdata.com/http//www.naturalearthdata.com/download/{resolution}m/{category}/ne_{resolution}m_{layer}.zip'  # noqa
    return template_url.format(layer=layer, category=category, resolution=resolution)


def ne_filename(layer: str, resolution: int) -> str:
    return 'ne_{resolution}m_{layer}.shp'.format(resolution=resolution, layer=layer)


def natural_earth(source_dir: str, layer: str, resolution: int) -> List[Step]:
    check_resolution(resolution)
    check_layer(layer)

    dirname = os.path.join(source_dir, 'Natural_Earth')

    url = ne_url(layer, resolution)
    zip_path = os.path.join(dirname, url.split('/')[-1])

    raw_file = os.path.join(dirname, ne_filename(layer, resolution))

    return [
        Step(
            targets=zip_path,
            dependencies=[],
            commands=[
                ['wget', '--directory-prefix', dirname, url]
            ]
        ),

        Step(
            targets=raw_file,
            dependencies=zip_path,
            commands=[
                ['unzip', '-D', '-d', dirname, zip_path],
            ]
        )
    ]
