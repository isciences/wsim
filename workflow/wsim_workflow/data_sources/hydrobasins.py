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

from ..step import Step

import os
import sys

from typing import List

subdir = 'HydroBASINS'


def basins_for_region(reg: str, level: int) -> str:
    return 'hybas_lake_{}_lev{:02d}_v1c.shp'.format(reg, level)


def basins(source_dir: str, filename: str, level: int) -> List[Step]:
    dirname = os.path.join(source_dir, subdir)

    collapse_command = [
        '{BINDIR}/utils/collapse_feature_ids.py',
        '--output', os.path.join(dirname, filename)
    ]

    for region in ('af', 'ar', 'as', 'au', 'eu', 'gr', 'na', 'sa', 'si'):
        input_file = os.path.join(dirname, basins_for_region(region, level))
        if not os.path.exists(input_file):
            print("HydroBASINS file", input_file, "not found.", file=sys.stderr)
            print("HydroBASINS distribution policies prevent automatic downloading of this file.", file=sys.stderr)
            print("It must be manually downloaded from hydrosheds.org and extracted to", dirname, file=sys.stderr)
        collapse_command += ['--input', input_file]

    for field in ('HYBAS_ID', 'NEXT_DOWN', 'NEXT_SINK', 'MAIN_BAS'):
        collapse_command += ['--remap', field]

    return [
        # we cannot automate the download of HydroBASINS data, so we don't list any dependencies here
        # and just let the command fail if the needed files are not present
        Step(
            targets=os.path.join(dirname, filename),
            dependencies=None,
            commands=[
                collapse_command
            ]
        )

    ]


def downstream_ids(source_dir: str, basins_file: str, ids_file: str) -> List[Step]:
    basin_path = os.path.join(source_dir, subdir, basins_file)
    ids_path = os.path.join(source_dir, subdir, ids_file)

    return [
        Step(
            targets=ids_path,
            dependencies=basin_path,
            commands=[
                [
                    '{BINDIR}/utils/table2nc.R',
                    '--input', basin_path,
                    '--output', ids_path,
                    '--column', 'NEXT_DOWN',
                    '--fid', 'HYBAS_ID'
                ]
            ]
        )
    ]
