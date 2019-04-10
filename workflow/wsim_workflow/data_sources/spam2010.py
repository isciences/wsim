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
from ..paths import Method

SUBDIR = 'SPAM2010'


def production(*, source_dir: str) -> List[Step]:
    dirname = os.path.join(source_dir, SUBDIR)
    url = 'https://s3.amazonaws.com/mapspam/2010/v1.0/geotiff/spam2010v1r0_global_prod.geotiff.zip'
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
        )
    ]


def spam_zip(source_dir: str) -> str:
    return os.path.join(source_dir, SUBDIR, 'spam2010v1r0_global_prod.geotiff.zip')


def allocate_spam_production(*, method: Method, spam_zip: str, area_fractions: str, output: str) -> List[Step]:

    return [
        Step(
            targets=output,
            dependencies=[spam_zip, area_fractions],
            commands = [
                [
                    os.path.join('{BINDIR}', 'utils', 'spam2010', 'allocate_spam_production.R'),
                    '--spam_zip', spam_zip,
                    '--area_fractions', area_fractions,
                    '--method', method.value,
                    '--output', output
                ]
            ]
        )
    ]
