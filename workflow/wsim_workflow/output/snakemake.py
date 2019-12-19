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

import io

from typing import Mapping, Optional

from ..step import Step

DEFAULT_FILENAME = 'Snakefile'


def header() -> str:
    return ""


def write_step(step: Step, keys: Optional[Mapping[str, str]] = None) -> str:

    if keys is None:
        keys = {}

    buff = io.StringIO()

    deps = sorted(list(step.dependencies))
    targets = sorted(list(step.targets))

    buff.write('rule:\n')
    buff.write('    input: [' + ', '.join('"' + d.format_map(keys) + '"' for d in deps) + ']\n')
    buff.write('    output: [' + ','.join('"' + t.format_map(keys) + '"' for t in targets) + ']\n')
    buff.write('    shell:\n')
    buff.write('        """\n')

    for command in step.get_mkdir_commands() + step.commands:
        command_txt = ' '.join(command).format_map(keys)
        for i, d in enumerate(deps):
            command_txt = command_txt.replace(d, '{input[' + str(i) + ']}')
        for i, d in enumerate(targets):
            command_txt = command_txt.replace(d, '{output[' + str(i) + ']}')

        buff.write('        ' + command_txt + '\n')

    buff.write('        """\n')

    buff.seek(0)
    return buff.read()
