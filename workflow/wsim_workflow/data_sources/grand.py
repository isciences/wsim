# Copyright (c) 2018-2020 ISciences, LLC.
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


def dam_locations(source_dir: str) -> str:
    return os.path.join(source_dir, 'GRanD', 'GRanD_dams_v1_3.shp')


def download_grand(source_dir: str) -> List[Step]:
    dirname = os.path.join(source_dir, 'GRanD')
    # url = None # Login required to download from SEDAC; GWSP appears to be down

    zip_path = os.path.join(dirname, 'GRanD_Version_1_3.zip')

    return [
        Step(
             targets=zip_path,
             dependencies=[],
             commands=[
                 ['echo', 'GRanD is not currently available for automated download.'],
                 ['echo', 'Please manually place', zip_path, 'in', dirname],
                 ['false']
                 # [ 'wget', '--directory-prefix', dirname, url ]
             ]
         ),

        # Unzip data
        Step(
            targets=dam_locations(source_dir),
            dependencies=zip_path,
            commands=[
                ['unzip', '-d', dirname, '-j', '-D', zip_path],
            ]
        )
    ]
