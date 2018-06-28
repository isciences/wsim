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

def global_tawc(*, source_dir, filename, resolution):
    dirname = os.path.join(source_dir, 'ISRIC')
    url = 'ftp://ftp.isric.org/wise/wise_30sec_v1.zip'
    zip_path = os.path.join(dirname, url.split('/')[-1])
    raw_file = os.path.join(dirname, 'HW30s_FULL.txt') # there are others, but might as well avoid a multi-target rule
    full_res_file = os.path.join(dirname, 'wise_30sec_v1_tawc.tif')

    return [
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
                    'wise_30sec_v1/Interchangeable_format/HW30s_FULL.txt',
                    'wise_30sec_v1/Interchangeable_format/wise_30sec_v1.tif',
                    'wise_30sec_v1/Interchangeable_format/wise_30sec_v1.tsv'
                ],
                [ 'touch', raw_file ]
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
        ),

        # Aggregate TAWC data
        Step(
            targets=filename,
            dependencies=full_res_file,
            commands=[
                [
                    os.path.join('{BINDIR}', 'utils', 'aggregate.R'),
                    '--res', str(resolution),
                    '--input', full_res_file,
                    '--output', filename
                ]
            ]
        )
    ]

