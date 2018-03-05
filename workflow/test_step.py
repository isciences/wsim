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

import unittest

from step import Step

class TestStep(unittest.TestCase):

    def test_empty_inputs_ignored(self):
        s = Step(targets=['a', None, 'b'],
                 dependencies=[None, 'c'],
                 commands=[['cat', 'c', '>', 'a'],
                           None,
                           ['wc', 'a', '>', 'b']])

        self.assertEqual(2, len(s.targets))
        self.assertEqual(1, len(s.dependencies))
        self.assertEqual(2, len(s.commands))

    def test_filenames_expanded(self):
        s = Step(targets='fit.nc',
                 dependencies='values[2014:2016].nc::Ws',
                 commands=['fitit'])

        self.assertSetEqual(
            {'values2014.nc', 'values2015.nc', 'values2016.nc'},
            s.dependencies
        )

    def test_step_merge(self):
        step1 = Step(targets='frosting',
                     dependencies=['water', 'sugar'],
                     commands=[['make', 'frosting']])
        step2 = Step(targets='cake',
                     dependencies=['frosting', 'flour', 'water'],
                     commands=[
                         ['bake', 'cake'],
                         ['apply', 'frosting']
                     ])
        step3 = Step(targets='party',
                     dependencies=['cake', 'presents'],
                     commands=[
                         ['eat', 'cake'],
                         ['open', 'presents']
                     ])

        combined = step1.merge(step2, step3)

        self.assertSetEqual(combined.targets, { 'cake', 'frosting', 'party' })
        self.assertSetEqual(combined.dependencies, { 'flour', 'water', 'sugar', 'presents' })
        self.assertListEqual(
            combined.commands,
            [
                ['make', 'frosting'],
                ['bake', 'cake'],
                ['apply', 'frosting'],
                ['eat', 'cake'],
                ['open', 'presents']
            ])

    def test_require(self):
        meta = Step.create_meta('party')

        meta.require(
            Step(targets='cake',
                 dependencies=['frosting', 'base'],
                 commands=[['a', 'b', 'c']]),
            Step(targets='presents',
                 dependencies=['money', 'ideas'],
                 commands=[['purchase']])
        )

        self.assertSetEqual(meta.dependencies, { 'cake', 'presents' })
        self.assertSetEqual(meta.targets, { 'party' })
        self.assertListEqual(meta.commands, [])
