# Copyright (c) 2022 ISciences, LLC.
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
import sys

from ..step import Step

from typing import List

SUBDIR = 'GPW'


def download(source_dir: str, year: int, resolution: str) -> List[Step]:
    return [Step(
        targets=population_density(source_dir, year, resolution),
        commands=[
            ['echo', 'GPW data must be downloaded manually.'],
            ['false']
        ]
    )]


def population_density(source_dir: str, year: int, resolution: str) -> str:
    return os.path.join(source_dir, SUBDIR, 'gpw_v4_population_density_rev11_{year}_{resolution}.tif'.format(year=year, resolution=resolution))