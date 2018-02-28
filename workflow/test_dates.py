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

from dates import *

class TestDates(unittest.TestCase):

    def test_parse_yearmon(self):
        self.assertTupleEqual(
            (1948, 2),
            parse_yearmon('194802')
        )

    def test_format_yearmon(self):
        self.assertEqual('194802', format_yearmon(1948, 2))
        self.assertEqual('001503', format_yearmon(15, 3))

    def test_get_yearmons(self):
        my_existence = list(get_yearmons('198402', '201802'))
        self.assertEqual(34*12 + 1, len(set(my_existence)))
        self.assertEqual('198402', my_existence[0])
        self.assertEqual('201802', my_existence[-1])

    def test_get_last_day_of_month(self):
        self.assertEqual(30, get_last_day_of_month('201709'))
        self.assertEqual(28, get_last_day_of_month('200102'))
        self.assertEqual(29, get_last_day_of_month('200002'))

    def test_get_next_yearmons(self):
        self.assertListEqual(
            ['201711', '201712', '201801'],
            get_next_yearmons('201710', 3)
        )

    def test_get_previous_yearmon(self):
        self.assertEqual('201712', get_previous_yearmon('201801'))
        self.assertEqual('201711', get_previous_yearmon('201712'))

    def test_rolling_window(self):
        self.assertListEqual(
            ['201711', '201712', '201801'],
            rolling_window('201801', 3)
        )

    def test_days_in_month(self):
        days = days_in_month('200002')

        self.assertEqual(29, len(days))
        self.assertEqual('20000201', days[0])
        self.assertEqual('20000229', days[-1])
