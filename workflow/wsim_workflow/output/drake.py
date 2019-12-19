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

from typing import Optional, Mapping

import io

from .output_modules import creation_string, add_line_continuation_characters, substitute_tokens, write_command
from ..step import Step

DEFAULT_FILENAME = 'Drakefile'


def header() -> str:
    return '; ' + creation_string() + '\n'


def write_step(step: Step,
               keys: Optional[Mapping[str, str]] = None) -> str:
    if keys is None:
        keys = {}

    buff = io.StringIO()

    if step.comment:
        buff.write('; ' + step.comment + '\n')

    buff.write(', '.join(step.targets))
    buff.write(' <- ')
    buff.write(', '.join(step.dependencies))
    buff.write('\n')

    for command in step.get_mkdir_commands() + step.commands:
        command = add_line_continuation_characters(command)
        command = substitute_tokens(command, keys)

        write_command(buff, command, indent='  ')

    return buff.getvalue()
