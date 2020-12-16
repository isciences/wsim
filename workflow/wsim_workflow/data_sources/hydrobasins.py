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

    steps = []

    region_shapefiles = []

    urls = {
        7: {
            "af": "https://www.dropbox.com/sh/hmpwobbz9qixxpe/AADq061MpgZ6oIGCHVx88h7pa/HydroBASINS/customized/af/hybas_lake_af_lev07_v1c.zip?dl=0",
            "ar": "https://www.dropbox.com/sh/hmpwobbz9qixxpe/AABRjqi-X0L4Pw2S5Id8oTSla/HydroBASINS/customized/ar/hybas_lake_ar_lev07_v1c.zip?dl=0",
            "as": "https://www.dropbox.com/sh/hmpwobbz9qixxpe/AABX7JdR-t6_7XBiJ6eODhzNa/HydroBASINS/customized/as/hybas_lake_as_lev07_v1c.zip?dl=0",
            "au": "https://www.dropbox.com/sh/hmpwobbz9qixxpe/AAAtjgJ1ecAth_xTqTOMMLoka/HydroBASINS/customized/au/hybas_lake_au_lev07_v1c.zip?dl=0",
            "eu": "https://www.dropbox.com/sh/hmpwobbz9qixxpe/AAChdnYlULsLOeHoB7xyhocna/HydroBASINS/customized/eu/hybas_lake_eu_lev07_v1c.zip?dl=0",
            "gr": "https://www.dropbox.com/sh/hmpwobbz9qixxpe/AADI8O-mYe2NWcSUe_lG3Pjua/HydroBASINS/customized/gr/hybas_lake_gr_lev07_v1c.zip?dl=0",
            "na": "https://www.dropbox.com/sh/hmpwobbz9qixxpe/AAA_3UhlmJEvQT2RD0qHYA7Da/HydroBASINS/customized/na/hybas_lake_na_lev07_v1c.zip?dl=0",
            "sa": "https://www.dropbox.com/sh/hmpwobbz9qixxpe/AAA19UgHwHP5Ba_6neYKz8Vna/HydroBASINS/customized/sa/hybas_lake_sa_lev07_v1c.zip?dl=0",
            "si": "https://www.dropbox.com/sh/hmpwobbz9qixxpe/AAAMjQF2ygqQNLYfYJuhAQkJa/HydroBASINS/customized/si/hybas_lake_si_lev07_v1c.zip?dl=0"
        }
    }

    for region in ('af', 'ar', 'as', 'au', 'eu', 'gr', 'na', 'sa', 'si'):
        url = urls[level][region]

        input_file = os.path.join(dirname, basins_for_region(region, level))
        zip_file = os.path.join(dirname, basins_for_region(region, level).replace('.shp', '.zip'))

        steps += [
            Step(targets=zip_file,
                 dependencies=[],
                 commands=[
                     ['wget', '-O', zip_file, url]
                 ]),
            Step(targets = input_file,
                 dependencies = zip_file,
                 commands = [
                     ['unzip',
                      '-d', dirname,
                      '-n',  # don't overwrite existing (needed because same docs are in every ZIP)
                      zip_file]
                 ])
        ]

        region_shapefiles.append(input_file)

    for f in region_shapefiles:
        collapse_command += ['--input', f]

    for field in ('HYBAS_ID', 'NEXT_DOWN', 'NEXT_SINK', 'MAIN_BAS'):
        collapse_command += ['--remap', field]

    steps.append(
        Step(
            targets=os.path.join(dirname, filename),
            dependencies=region_shapefiles,
            commands=[
                collapse_command
            ]
        )
    )

    return steps


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
