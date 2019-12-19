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


def download_monthly_temperature(*, yearmon: str, workdir: str, output_filename: str) -> List[Step]:
    assert yearmon >= '197901'

    # FIXME Need some sort of locking mechanism so that multiple calls to this script don't try to download the same file.
    # Could pre-empt and download in global_prep_steps??

    return [
        Step(
            targets=output_filename,
            dependencies=[],
            commands=[
                [
                    os.path.join('{BINDIR}', 'utils', 'noaa_cpc_daily_temp', 'get_cpc_monthly_mean_temperature.R'),
                    '--yearmon', yearmon,
                    '--workdir', workdir,
                    '--output', output_filename,
                ]
            ]
        )
    ]
