# Copyright (c) 2020 ISciences, LLC.
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


def download_precl(*, yearmon: str, output_filename: str) -> List[Step]:
    return [
        Step(
            targets=output_filename,
            dependencies=[],
            commands=[
                [
                    os.path.join('{BINDIR}', 'utils', 'precl', 'get_precl.R'),
                    '--yearmon', yearmon,
                    '--output', output_filename,
                ]
            ]
        )
    ]
