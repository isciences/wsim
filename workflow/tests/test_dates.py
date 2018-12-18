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

from wsim_workflow.dates import *

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

    def test_add_years(self):
        self.assertEqual('2004', add_years('1996', 8))
        
        self.assertEqual('2004', add_years('2013', -9))

    def test_add_months(self):
        self.assertEqual('200406', add_months('199606', 8*12))

        self.assertEqual('200406', add_months('200507', -13))
        self.assertEqual('200312', add_months('200401', -1))

    def test_add_days(self):
        self.assertEqual('20170225', add_days('20160225', 366))

        self.assertEqual('20000229', add_days('20000301', -1))

    def test_date_range(self):
        self.assertListEqual(
            ['1999', '2000', '2001'],
            expand_date_range('1999', '2001', 1)
        )

        # Can use step > 1
        self.assertListEqual(
            ['1999',  '2001'],
            expand_date_range('1999', '2001', 2)
        )

        # Overshoots are ignored
        self.assertListEqual(
            ['1999'],
            expand_date_range('1999', '2001', 3)
        )

        # also works with months
        self.assertListEqual(
            ['201711', '201801', '201803'],
            expand_date_range('201711', '201803', 2)
        )

        # or days
        self.assertListEqual(
            ['20180221', '20180222', '20180223'],
            expand_date_range('20180221', '20180223', 1)
        )

    def test_next_occurrence_of_month(self):
        self.assertEqual('201505', next_occurence_of_month('201504', 5))
        self.assertEqual('201505', next_occurence_of_month('201505', 5))
        self.assertEqual('201605', next_occurence_of_month('201506', 5))

        with self.assertRaises(Exception):
            next_occurence_of_month('201504', 13)

    def test_available_date_range(self):
        self.assertEqual('[201501:201512:1]', available_yearmon_range(window=1, start_year=2015, end_year=2015))
        self.assertEqual('[201504:201504:12]', available_yearmon_range(window=1, month=4, start_year=2015, end_year=2015))

        self.assertEqual('[201503:201712:1]', available_yearmon_range(window=3, start_year=2015, end_year=2017))
        self.assertEqual('[201508:201512:1]', available_yearmon_range(window=8, start_year=2015, end_year=2015))
        self.assertEqual('[201503:201703:12]', available_yearmon_range(window=3, month=3, start_year=2015, end_year=2017))
        self.assertEqual('[201603:201703:12]', available_yearmon_range(window=6, month=3, start_year=2015, end_year=2017))

        with self.assertRaises(Exception):
            available_yearmon_range(window=14, start_year=2015, end_year=2015)

    def test_lead_months(self):
        self.assertEqual(0, get_lead_months('201812', '201812'))
        self.assertEqual(2, get_lead_months('201812', '201902'))

        with self.assertRaises(Exception):
            get_lead_months('201901', '201812')
