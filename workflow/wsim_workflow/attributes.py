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

from typing import List, Optional


def integration_window(*, var: Optional[str], months: int) -> str:
    return '{}integration_window_months={}'.format('' if var is None else var + ':',
                                                   months)


def standard_attrs(*,
                   yearmon: str,
                   window: int,
                   target: Optional[str],
                   model: Optional[str],
                   member: Optional[str]) -> List[str]:

    attrs = [
        'yearmon={}'.format(yearmon),
        'target={}'.format(target if target else yearmon),
        'window={}'.format(window)
    ]

    if model:
        attrs.append('model={}'.format(model))
    if member:
        attrs.append('member={}'.format(member))

    return attrs
