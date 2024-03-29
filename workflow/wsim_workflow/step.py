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

from . import dates

import os
import warnings

from typing import Union, Optional, List, Iterable, Set


def process_filename(txt: str) -> List[str]:
    """
    Strip out variable definitions used by some WSIM tools, and expand
    date ranges present in the filename
    """
    filename = str(txt).split('::')[0]
    return dates.expand_filename_dates(filename)


def coerce_to_list(thing) -> List:
    if thing is None:
        return []
    if type(thing) is str:
        return [thing]
    return thing


ZeroOrMoreStrings = Union[str, List[str], Set[str], None]


class Step:

    def __eq__(self, other):
        if not isinstance(other, Step):
            raise Exception("Cannot compare Step to non-Step")

        mostly_equal = self.targets == other.targets \
            and self.dependencies == other.dependencies \
            and self.commands == other.commands

        if not mostly_equal:
            return False

        if self.consumes != other.consumes or self.working_directories != other.working_directories or self.lock != other.lock:
            warnings.warn("Almost-equal steps being compared for equality. This is not expected.")

        return True

    def __hash__(self):
        return hash(tuple(sorted(self.targets)))

    def __init__(self, *,
                 targets: ZeroOrMoreStrings=None,
                 dependencies: ZeroOrMoreStrings=None,
                 commands: Optional[List[List[str]]]=None,
                 comment: Optional[str]=None,
                 consumes: ZeroOrMoreStrings=None,
                 working_directories: ZeroOrMoreStrings=None,
                 lock: Optional[str] = None):
        """
        Initialize a workflow step

        :param targets:      a string or list of strings indicating outputs from the step
        :param dependencies: a string or list of strings indicating dependencies of the step
        :param consumes:     a string or list of strings indicating files destroyed by the step
                             (relevant only when multiple steps are merged)
        :param working_directories a string or list of strings indicating directories that should be
                             created, if not already present, before this step executes. Any directory
                             included in a target is implied and does not need to be specified.

        :param commands:     a list of commands, where each command is represented as a list of tokens
        :param comment:      an optional text comment to be associated with the step
        """

        targets = coerce_to_list(targets)
        dependencies = coerce_to_list(dependencies)
        consumes = coerce_to_list(consumes)
        commands = coerce_to_list(commands)
        working_directories = coerce_to_list(working_directories)

        self.commands = [c for c in commands if c is not None]
        self.consumes = {t for t in consumes if t is not None}

        self.targets = set()
        for t in targets:
            if t is not None and t != '/dev/null':
                self.targets |= set(process_filename(t))

        self.working_directories = set(working_directories) | {os.path.dirname(target) for target in self.targets}

        self.dependencies = set()
        for d in dependencies:
            if d is not None:
                self.dependencies |= set(process_filename(d))

        self.comment = comment
        self.lock = lock

        self.validate()

    @classmethod
    def make_empty(cls):
        return Step()

    @classmethod
    def create_meta(cls, meta_step_name: str, dependencies: Optional[List[str]]=None):
        """
        Utility method to create a step with no commands, used only
        as a convenient way to refer to many related steps at once
        (e.g., "all_composites")
        """
        return Step(targets=[meta_step_name], dependencies=dependencies, commands=None)

    def merge(self, *others: "Step") -> "Step":
        """
        Merge another step into this one, returning a combined step.
        Commands for the other step will be sequenced after commands
        for this step. Dependencies of the other step that are
        supplied by this step will be removed from the dependency list.
        """

        assert not self.lock  # Not implemented yet

        combined_targets = set(self.targets)
        combined_dependencies = set(self.dependencies)
        combined_commands = list(self.commands)
        combined_consumes = set(self.consumes)
        combined_working_directories = set(self.working_directories)

        for other in others:
            assert not other.lock  # Not implemented yet

            # Add dependencies of other step that are not supplied by a
            # previous step to our dependency list
            for d in other.dependencies:
                if d not in combined_targets:
                    combined_dependencies.add(d)

            # Add all targets of other step to our target list
            combined_targets |= other.targets
            combined_working_directories |= other.working_directories

            combined_commands += other.commands

            for t in other.consumes:
                combined_targets.remove(t)
                combined_consumes.add(t)

        return Step(
            targets=combined_targets,
            dependencies=combined_dependencies,
            commands=combined_commands,
            consumes=combined_consumes,
            working_directories=combined_working_directories
        )

    def require(self, *others) -> Iterable["Step"]:
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

    def replace_targets_with_tag_file(self, tag_file_name: str) -> "Step":
        """
        Replace a long list of targets with a single tag file. This is
        useful when Make struggles with a large number of targets, and
        the targets are only required by downstream processes as a
        complete set.

        Returns the step object, to enable use in chaining.
        """
        self.commands.append(['touch', tag_file_name])
        self.targets = {tag_file_name}
        self.working_directories.add(os.path.dirname(tag_file_name))

        return self

    def replace_dependencies(self, *deps) -> "Step":
        """
        Replace a long list of dependencies with a tag file. This can
        be used to consume the output of a step that produces a tag file.

        Returns the step object, to enable use in chaining.
        """
        self.dependencies = set(deps)

        return self

    def get_mkdir_commands(self) -> List[List[str]]:
        """
        Get commands necessary to create directories for all targets
        """
        directories_to_create = [d for d in sorted(self.working_directories) if d != '']

        if directories_to_create:
            return [['mkdir', '-p'] + directories_to_create]
        else:
            return []

    def validate(self) -> None:
        for t in self.targets:
            if type(t) is not str:
                raise TypeError("Non-string target: ", t)
        for d in self.dependencies:
            if type(d) is not str:
                raise TypeError("Non-string dependency: ", d)
        for c in self.commands:
            if type(c) is not list:
                raise TypeError("Non-list command: ", c)
            for token in c:
                if type(token) is not str:
                    print(c)
                    raise TypeError("Non-string command token: ", str(token))

    def __str__(self) -> str:
        s = "Targets:\n"
        for t in sorted(self.targets):
            s += ' - ' + t + '\n'
        s += "Dependencies:\n"
        for d in sorted(self.dependencies):
            s += ' - ' + d + '\n'
        s += "Commands:\n"
        for c in self.commands:
            s += ' - ' + ' '.join(c) + '\n'

        return s
