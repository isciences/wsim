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

import re
import unittest

from wsim_workflow.step import Step
from wsim_workflow.output.gnu_make import write_step

def unformat(recipe):
    """
    Remove indentation, alignment from a Makefile recipe
    """
    recipe = re.sub('[\\\\]\n', ' ', recipe)
    recipe = '\n'.join(re.sub('[\s]+', ' ', line).strip() for line in recipe.split('\n') if line != '')
    return recipe

class TestGnuMake(unittest.TestCase):

    def test_tab_indentation(self):
        # Make requires that all command lines be tab-indented
        s = Step(targets=['a', 'b'], dependencies=['c', 'd'], commands=[ ['echo', 'c', '>', 'a'], ['echo', 'd', '>', 'b'] ])

        lines = write_step(s).strip().split('\n')
        for line in lines[1:]:
            self.assertEqual(line[0], '\t')

    def test_variable_substitution(self):
        s = Step(targets=['{ROOT_DIR}/fizz'],
                 dependencies=['{SOURCE_DIR}/buzz'],
                 commands=[ ['echo', '{SOURCE_DIR}/buzz', '>', '{ROOT_DIR}/fizz'] ])

        step_text = write_step(s, dict(ROOT_DIR='/tmp/root', SOURCE_DIR='/tmp/src'))

        self.assertTrue('/tmp/root/fizz' in step_text)
        self.assertTrue('/tmp/src/buzz' in step_text)

        self.assertFalse('ROOT_DIR' in step_text)
        self.assertFalse('SRC_DIR' in step_text)

        self.assertFalse('{' in step_text)
        self.assertFalse('}' in step_text)

    def test_variable_substitution_error(self):
        s = Step(targets='a', dependencies='b', commands=[ ['{PROGRAM}', 'a', 'b']])

        self.assertRaises(KeyError, lambda : write_step(s, dict(PROG='q')))

    def test_step_comments(self):
        s = Step(targets='a', dependencies=[], commands=[['touch', 'a']], comment='Step to build a')

        self.assertEqual(write_step(s).split('\n')[0], '# Step to build a')

    def test_pattern_rule_conversion(self):
        s = Step(targets=['a.txt', 'b.txt'], dependencies='source.txt', commands=[['process', 'source.txt', 'a.txt', 'b.txt']])

        declaration_line, command_line = write_step(s).split('\n')[:2]

        self.assertTrue('a%txt' in declaration_line)
        self.assertTrue('b%txt' in declaration_line)
        self.assertTrue('source%txt' in declaration_line)

        self.assertTrue('a.txt' in command_line)
        self.assertTrue('b.txt' in command_line)
        self.assertTrue('source.txt' in command_line)

    def test_target_directories_created_but_only_once(self):
        s = Step(targets=['/tmp/fizz/fuzz/ok.txt', '/src/junk.h', '/src/junk.c'], dependencies=[], commands=[['do_something']])

        commands = unformat(write_step(s)).split('\n')[1:]

        self.assertTrue('mkdir -p /src /tmp/fizz/fuzz' in commands)
        self.assertEqual(2, len(commands))

    def test_commands_arguments_aligned(self):
        s = Step(targets='outputs/results.nc', dependencies='inputs.nc', commands=[['process.py', '--input', 'inputs.nc', '--output', 'outputs/results.nc', '--compress', '3', '--nohistory']])

        command_lines = [line.strip() for line in write_step(s).split('\n') if line.startswith('\t')]

        self.assertEqual(7, len(command_lines))
        self.assertTrue(all(line.startswith('mkdir') or
                            line.startswith('process.py') or
                            line.startswith('-') for line in command_lines))
