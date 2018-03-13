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
        '# Generated on {} by {}'.format(datetime.datetime.now(), ' '.join(sys.argv)),
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
    txt = ""
    if step.comment:
        txt += '# ' + step.comment + '\n'

    # Rule Description
    txt += target_string(step).format_map(keys) + \
           target_separator(use_order_only_rules) + \
           dependency_string(step).format_map(keys) + '\n'

    # Recipe
    for command in step.get_mkdir_commands() + step.commands:
        # Split command-line arguments into individual lines for readability
        # Add a \ to the end of the previous token to indicate a multiline
        # continuation of a single command
        for i in range(len(command)):
            if command[i].startswith('-'):
                command[i-1] += ' \\'

        txt += '\t' # Make requires that all lines in recipe start with a tab
        for token in command:
            try:
                txt += token.format_map(keys)
            except Exception as e:
                print("Error subbing", token, "with", keys, "in step for", step.targets, file=sys.stderr)
                raise e
            if token.endswith('\\'):
                txt += '\n\t   '
            else:
                txt += ' '

        txt += '\n'
    return txt
