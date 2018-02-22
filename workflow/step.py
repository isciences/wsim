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

import os
import sys

class Step:

    def __init__(self, targets, dependencies, commands, comment=None):
        """
        Initialize a workflow step

        :param targets:      a string or list of strings indicating outputs from the step
        :param dependencies: a string or list of strings indicating dependencies of the step
        :param commands:     a list of
        :param comment:      an optional text comment to be associated with the step
        """
        if type(targets) is str:
            targets = [targets]

        if type(dependencies) is str:
            dependencies = [dependencies]

        self.targets = targets
        self.dependencies = dependencies
        self.commands = commands
        self.comment = comment

    def use_pattern_rules(self):
        """
        Determine if we should use pattern-style rules when writing a Step
        as a Makefile rule. This can be necessary because GNU Make only supports
        multiple targets in a single rule when using pattern-style rules.
        In this case, we fake a pattern by replacing periods in our filesnames with %

        :return: True if pattern rules should be used
        """
        return len(self.targets) > 1

    @classmethod
    def patternize(cls, filenames):
        """
        Convert each target or dependency in a list to a pattern
        :param filenames: list of targets or dependencies
        :return: converted list
        """
        return [filename.replace('.', '%') for filename in filenames]

    def patternize_if_needed(self, filenames):
        """
        Convert filenames into patterns, if needed
        :param filenames: list of targets or dependencies
        :return: possibly converted list
        """
        return self.patternize(filenames) if self.use_pattern_rules() else filenames

    def target_string(self):
        """
        Generate the target portion of the dependency string (the left-hand-side)
        """
        return ' '.join(self.patternize_if_needed(self.targets))

    def dependency_string(self):
        """
        Generate the target portion of the dependency string (the right-hand-side)
        """
        return ' '.join(self.patternize_if_needed(self.dependencies))

    @classmethod
    def target_separator(cls, use_order_only_rules):
        if use_order_only_rules:
            return ' : | '
        else:
            return ' : '

    def get_mkdir_commands(self):
        """
        Get commands necessary to create directories for all targets
        """
        dirs = set([os.path.dirname(target) for target in self.targets])

        return [ ['mkdir', '-p', dir ] for dir in sorted(dirs) if dir != '']

    def get_text(self, keys=None, use_order_only_rules=True):
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
        if self.comment:
            txt += '# ' + self.comment + '\n'

        # Rule Description
        txt += self.target_string().format_map(keys) + \
               self.target_separator(use_order_only_rules) + \
               self.dependency_string().format_map(keys) + '\n'

        # Recipe
        for command in self.get_mkdir_commands() + self.commands:
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
                    print("Error subbing", token, "with", keys, file=sys.stderr)
                    raise e
                if token.endswith('\\'):
                    txt += '\n\t   '
                else:
                    txt += ' '

            txt += '\n'
        return txt

