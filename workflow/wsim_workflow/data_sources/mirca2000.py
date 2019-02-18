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

SUBDIR = 'MIRCA2000'


def _condensed_crop_calendar(*, source_dir: str) -> List[Step]:
    dirname = os.path.join(source_dir, SUBDIR)
    url = 'https://hessenbox-a10.rz.uni-frankfurt.de/dl/fiBX48XXU1GQumNk7iAsoXyG/condensed_cropping_calendars.zip'
    zip_path = os.path.join(dirname, url.split('/')[-1])

    gz_files = [
        os.path.join(dirname, 'cropping_calendar_rainfed.txt.gz'),
        os.path.join(dirname, 'cropping_calendar_irrigated.txt.gz')
    ]
    txt_files = [
        os.path.join(dirname, 'cropping_calendar_rainfed.txt'),
        os.path.join(dirname, 'cropping_calendar_irrigated.txt')
    ]

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

        # Unzip data
        Step(
            targets=gz_files,
            dependencies=zip_path,
            commands=[
                [
                    'unzip', '-D', '-j', zip_path, '-d', dirname
                ],
            ]
        ),

        # Unzip data (again)
        Step(
            targets=txt_files,
            dependencies=gz_files,
            commands=[['gunzip', f] for f in gz_files]
        ),
    ]


def _regions(*, source_dir: str) -> List[Step]:
    dirname = os.path.join(source_dir, SUBDIR)
    url = 'https://hessenbox-a10.rz.uni-frankfurt.de/dl/fi5tzYpNuExZ5KLMVoBZh3uy/unit_code_grid.zip'
    zip_path = os.path.join(dirname, url.split('/')[-1])

    gz_file = os.path.join(dirname, 'unit_code.asc.gz')
    grid_file = os.path.join(dirname, 'unit_code.asc')

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

        # Unzip
        Step(
            targets=gz_file,
            dependencies=zip_path,
            commands=[
                [
                    'unzip', '-D', '-j', zip_path, '-d', dirname
                ]
            ]
        ),

        Step(
            targets=grid_file,
            dependencies=gz_file,
            commands=[
                ['gunzip',  gz_file]
            ]
        )
    ]


def crop_calendars(*, source_dir: str) -> List[Step]:
    dirname = os.path.join(source_dir, SUBDIR)

    regions_grid = os.path.join(dirname, 'unit_code.asc')

    steps = _regions(source_dir=source_dir) + _condensed_crop_calendar(source_dir=source_dir)

    for method in ('rainfed', 'irrigated'):
        calendar = os.path.join(dirname, 'calendar_{}.nc'.format(method))
        condensed_calendar = os.path.join(dirname, 'cropping_calendar_{}.txt'.format(method))

        steps += [
            Step(
                targets=calendar,
                dependencies=[condensed_calendar, regions_grid],
                commands=[
                    [
                        os.path.join('{BINDIR}', 'utils', 'mirca2000', 'process_mirca_2000_crop_calendar.R'),
                        '--condensed_calendar', condensed_calendar,
                        '--regions', regions_grid,
                        '--res', str(0.5),
                        '--output', calendar
                    ]
                ]
            )
        ]

    return steps
