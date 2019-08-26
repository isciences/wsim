# Copyright (c) 2019 ISciences, LLC.
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

SUBDIR = 'TIGER'


def counties_shp(source_dir: str) -> str:
    return os.path.join(source_dir, SUBDIR, 'tl_2018_us_county.shp')


def counties(*, source_dir: str) -> List[Step]:
    dirname = os.path.join(source_dir, SUBDIR)
    url = 'https://www2.census.gov/geo/tiger/TIGER2018/COUNTY/tl_2018_us_county.zip'
    zip_path = os.path.join(dirname, url.split('/')[-1])

    return [
        # Download
        Step(
            targets=zip_path,
            dependencies=[],
            commands=[
                [
                    'wget',
                    '--directory-prefix', dirname,
                    url
                ]
            ]
        ),
        Step(
            targets=counties_shp(source_dir),
            dependencies=zip_path,
            commands=[
                ['unzip', '-D', '-d', dirname, zip_path],
            ]
        )
    ]
