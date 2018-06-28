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

from ..step import Step

def global_flow_direction(source_dir, filename, resolution):
    if resolution != 0.5:
        raise ValueError('Only half-degree resolution is provided by STN-30')

    dirname = os.path.join(source_dir, 'STN_30')
    extracted_filename = os.path.join(dirname, 'g_network.asc')
    url = 'http://www.wsag.unh.edu/Stn-30/v_6.01/global_30_minute_potential_network_v601_asc.zip'
    zip_path = os.path.join(dirname, url.split('/')[-1])

    return [
        # Download flow grid
        Step(
            targets=zip_path,
            dependencies=[],
            commands=[
                [ 'wget', '--directory-prefix', dirname, url ]
            ]
        ),

        # Unzip flow grid
        Step(
            targets=filename,
            dependencies=zip_path,
            commands=[
                [ 'unzip', '-j', zip_path, 'global_30_minute_potential_network_v601_asc/g_network.asc', '-d', dirname ],
                [ 'mv', extracted_filename, filename ] if extracted_filename != filename else None,
                [ 'touch', filename ] # Make extracted date modified > archive date modified
            ]
        )
    ]
