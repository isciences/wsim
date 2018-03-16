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

from output.output_modules import creation_string, add_line_continuation_characters, substitute_tokens, write_command

DEFAULT_FILENAME = 'Makefile'

def use_pattern_rules(step):
    """
    Determine if we should use pattern-style rules when writing a Step
    as a Makefile rule. This can be necessary because GNU Make only supports
    multiple targets in a single rule when using pattern-style rules.
    In this case, we fake a pattern by replacing periods in our filesnames with %

    :return: True if pattern rules should be used
    """
    return len(step.targets) > 1

def patternize(filenames):
    """
    Convert each target or dependency in a list to a pattern
    :param filenames: list of targets or dependencies
    :return: converted list
    """
    return [filename.replace('.', '%') for filename in filenames]

def patternize_if_needed(step, filenames):
    """
    Convert filenames into patterns, if needed
    :param filenames: list of targets or dependencies
    :return: possibly converted list
    """
    return patternize(filenames) if use_pattern_rules(step) else filenames

def target_string(step):
    """
    Generate the target portion of the dependency string (the left-hand-side)
    """
    return ' '.join(patternize_if_needed(step, sorted(list(step.targets))))

def dependency_string(step):
    """
    Generate the target portion of the dependency string (the right-hand-side)
    """
    return ' '.join(patternize_if_needed(step, sorted(list(step.dependencies))))

def target_separator(use_order_only_rules):
    if use_order_only_rules:
        return ' : | '
    else:
        return ' : '

def header():
    return '\n'.join([
        '# ' + creation_string(),
        '',
        '.DELETE_ON_ERROR:',  # Delete partially-created files on error or cancel
        '.SECONDARY:',        # Prevent removal of targets considered "intermediate"
        '.SUFFIXES:',         # Disable implicit rules
    ]) + 2*'\n'

def write_step(step, keys=None, use_order_only_rules=True):
    """
    Output this Step in the rule/recipe format used by GNU Make

    :param keys:                  optional dictionary of substitutions to make throughout
                                  the command (e.g., { 'BINDIR' : '/wsim' }
    :param use_order_only_rules:  if true, instructs make not to rebuild targets when the
                                  timestamp of dependencies is newer than targets
    :return:
    """
    if keys is None:
        keys = {}

    buff = io.StringIO()

    if step.comment:
        buff.write('# ' + step.comment + '\n')

    # Rule Description
    buff.write(target_string(step).format_map(keys))
    buff.write(target_separator(use_order_only_rules))
    buff.write(dependency_string(step).format_map(keys))
    buff.write('\n')

    # Recipe
    for command in step.get_mkdir_commands() + step.commands:
        command = add_line_continuation_characters(command)
        command = substitute_tokens(command, keys)

        write_command(buff, command, indent='\t')

    return buff.getvalue()

