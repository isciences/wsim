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
from os.path import join

from wsim_workflow.paths import DefaultWorkspace

class TestWorkspacePaths(unittest.TestCase):
    root = '/tmp'
    ws = DefaultWorkspace(root)

    def testState(self):
        # Observed data
        self.assertEqual(
            join(self.root, 'state', 'state_201612.nc'),
            self.ws.state(yearmon='201612')
        )

        # Forecast data
        self.assertEqual(
            join(self.root, 'state', 'state_201612_trgt201703_fcstCFS13.nc'),
            self.ws.state(yearmon='201612', target='201703', member='CFS13')
        )

    def testForcing(self):
        # Observed data
        self.assertEqual(
            join(self.root, 'forcing', 'forcing_201612.nc'),
            self.ws.forcing(yearmon='201612')
        )

        # Forecast data
        self.assertEqual(
            join(self.root, 'forcing', 'forcing_201612_trgt201703_fcstCFS13.nc'),
            self.ws.forcing(yearmon='201612', target='201703', member='CFS13')
        )

    def testResults(self):
        # Observed data
        self.assertEqual(
            join(self.root, 'results', 'results_1mo_201612.nc'),
            self.ws.results(yearmon='201612', window=1)
        )

        # Observed data
        self.assertEqual(
            join(self.root, 'results_integrated', 'results_24mo_201612.nc'),
            self.ws.results(yearmon='201612', window=24)
        )

        # Forecast data
        self.assertEqual(
            join(self.root, 'results', 'results_1mo_201612_trgt201703_fcstCFS13.nc'),
            self.ws.results(yearmon='201612', window=1, target='201703', member='CFS13')
        )

        self.assertEqual(
            join(self.root, 'results_integrated', 'results_36mo_201612_trgt201703_fcstCFS13.nc'),
            self.ws.results(yearmon='201612', target='201703', member='CFS13', window=36)
        )

    def testReturnPeriod(self):
        # Observed data
        self.assertEqual(
            join(self.root, 'rp', 'rp_1mo_201612.nc'),
            self.ws.return_period(yearmon='201612', window=1)
        )

        # Observed data
        self.assertEqual(
            join(self.root, 'rp_integrated', 'rp_24mo_201612.nc'),
            self.ws.return_period(yearmon='201612', window=24)
        )

        # Forecast data
        self.assertEqual(
            join(self.root, 'rp', 'rp_1mo_201612_trgt201703_fcstCFS13.nc'),
            self.ws.return_period(yearmon='201612', target='201703', member='CFS13', window=1)
        )

        self.assertEqual(
            join(self.root, 'rp_integrated', 'rp_36mo_201612_trgt201703_fcstCFS13.nc'),
            self.ws.return_period(yearmon='201612', target='201703', member='CFS13', window=36)
        )

    def testCompositeSummary(self):

        # Observed data
        self.assertEqual(
            join(self.root, 'composite', 'composite_1mo_201612.nc'),
            self.ws.composite_summary(yearmon='201612', window=1)
        )

        self.assertEqual(
            join(self.root, 'composite', 'composite_36mo_201612.nc'),
            self.ws.composite_summary(yearmon='201612', window=36)
        )

        # Forecast data
        self.assertEqual(
            join(self.root, 'composite', 'composite_1mo_201612_trgt201708.nc'),
            self.ws.composite_summary(yearmon='201612', target='201708', window=1)
        )

        self.assertEqual(
            join(self.root, 'composite', 'composite_6mo_201612_trgt201708.nc'),
            self.ws.composite_summary(yearmon='201612', target='201708', window=6)
        )

    def testReturnPeriodSummary(self):

        # Forecast data
        self.assertEqual(
            join(self.root, 'rp_summary', 'rp_summary_1mo_201612_trgt201708.nc'),
            self.ws.return_period_summary(yearmon='201612', target='201708', window=1)
        )

        self.assertEqual(
            join(self.root, 'rp_integrated_summary', 'rp_summary_6mo_201612_trgt201708.nc'),
            self.ws.return_period_summary(yearmon='201612', target='201708', window=6)
        )

    def testResultsSummary(self):

        # Forecast data
        self.assertEqual(
            join(self.root, 'results_summary', 'results_summary_1mo_201612_trgt201708.nc'),
            self.ws.results_summary(yearmon='201612', target='201708', window=1)
        )

        self.assertEqual(
            join(self.root, 'results_integrated_summary', 'results_summary_6mo_201612_trgt201708.nc'),
            self.ws.results_summary(yearmon='201612', target='201708', window=6)
        )
