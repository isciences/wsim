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

from paths import expand_filename_dates

import os
import sys

def process_filename(txt):
    """
    Strip out variable definitions used by some WSIM tools, and expand
    date ranges present in the filename
    """
    filename = str(txt).split('::')[0]
    return expand_filename_dates(filename)

class Step:

    def __init__(self, *, targets=None, dependencies=None, commands=None, comment=None):
        """
        Initialize a workflow step

        :param targets:      a string or list of strings indicating outputs from the step
        :param dependencies: a string or list of strings indicating dependencies of the step
        :param commands:     a list of
        :param comment:      an optional text comment to be associated with the step
        """

        if targets is None:
            targets = []
        elif type(targets) is str:
            targets = [targets]

        if dependencies is None:
            dependencies = []
        elif type(dependencies) is str:
            dependencies = [dependencies]

        if commands is None:
            commands = []

        self.commands = [c for c in commands if c is not None]

        self.targets = set()
        for t in targets:
            if t is not None and t != '/dev/null':
                self.targets |= set(process_filename(t))

        self.dependencies = set()
        for d in dependencies:
            if d is not None:
                self.dependencies |= set(process_filename(d))

        self.comment = comment

    @classmethod
    def create_meta(cls, meta_step_name, dependencies=None):
        """
        Utility method to create a step with no commands, used only
        as a convenient way to refer to many related steps at once
        (e.g., "all_composites")
        """
        return Step(targets=[meta_step_name], dependencies=dependencies, commands=None)

    def merge(self, *others):
        """
        Merge another step into this one, returning a combined step.
        Commands for the other step will be sequenced after commands
        for this step. Dependencies of the other step that are
        supplied by this step will be removed from the dependency list.
        """

        combined_targets = set(self.targets)
        combined_dependencies = set(self.dependencies)
        combined_commands = list(self.commands)

        for other in others:
            # Add dependencies of other step that are not supplied by a
            # previous step to our dependency list
            for d in other.dependencies:
                if d not in combined_targets:
                    combined_dependencies.add(d)

            # Add all targets of other step to our target list
            combined_targets = combined_targets | other.targets

            combined_commands += other.commands

        return Step(
            targets=combined_targets,
            dependencies=combined_dependencies,
            commands=combined_commands
        )

    def require(self, *others):
        """
        Add targets of other steps to this step's dependencies
        Useful in creating meta-steps such as "all_composites"

        As a convenience, return the arguments so that we can
        use concise constructs like this:

        steps += my_meta.require(*composite_indicators(month=6))
        """
        if len(others) == 1 and type(others[0] is list):
            others = others[0]

        for other in others:
            self.dependencies |= other.targets

        return others

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
        return ' '.join(self.patternize_if_needed(sorted(list(self.targets))))

    def dependency_string(self):
        """
        Generate the target portion of the dependency string (the right-hand-side)
        """
        return ' '.join(self.patternize_if_needed(sorted(list(self.dependencies))))

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

        return [ ['mkdir', '-p', d ] for d in sorted(dirs) if d != '']

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
                    print("Error subbing", token, "with", keys, "in step for", self.targets, file=sys.stderr)
                    raise e
                if token.endswith('\\'):
                    txt += '\n\t   '
                else:
                    txt += ' '

            txt += '\n'
        return txt

