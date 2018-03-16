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

import datetime
import sys

def creation_string():
    return 'Generated on {} by {}'.format(datetime.datetime.now(), ' '.join(sys.argv))

def add_line_continuation_characters(command_tokens):
    """
    Add a \ to the end of each command token that precedes an argument token (starting with -)
    """
    command_tokens = list(command_tokens) # make a copy

    for i, token in enumerate(command_tokens):
        if i > 0 and token.startswith('-'):
            command_tokens[i-1] += ' \\'

    return command_tokens

def substitute_tokens(command_tokens, keys):
    tokens_out = []

    for token in command_tokens:
        try:
            tokens_out.append(token.format_map(keys))
        except Exception as e:
            print("Error subbing", token, "with", keys, file=sys.stderr)
            raise e

    return tokens_out

def write_command(buff, command_tokens, indent):
    buff.write(indent)
    for token in command_tokens:
        if token.endswith('\\'):
            buff.write('\n' + indent + '  ')
        else:
            buff.write(' ')
    buff.write('\n')
