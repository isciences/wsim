# Copyright (c) 2018-2022 ISciences, LLC.
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

from wsim_workflow.paths import Basis, DefaultWorkspace


class TestWorkspacePaths(unittest.TestCase):
    root = '/tmp'
    ws = DefaultWorkspace(root, distribution='pe3', fit_start_year=1980, fit_end_year=2009)
    ws_flat = DefaultWorkspace(root, distribution_subdir=False)

    def test_state(self):
        # Observed data
        self.assertEqual(
            join(self.root, 'state', 'state_201612.nc'),
            self.ws.state(yearmon='201612')
        )

        # Forecast data
        self.assertEqual(
            join(self.root, 'state', 'state_201612_trgt201703_fcstcfsv2_CFS13.nc'),
            self.ws.state(yearmon='201612', target='201703', model='CFSv2', member='CFS13')
        )

    def test_forcing(self):
        # Observed data:
        self.assertEqual(
            join(self.root, 'forcing', 'forcing_1mo_201612.nc'),
            self.ws.forcing(yearmon='201612', window=1)
        )
        
        self.assertEqual(
            join(self.root, 'forcing_integrated', 'forcing_24mo_201612.nc'),
            self.ws.forcing(yearmon='201612', window=24)
        )
        
        # Observed basins:
        self.assertEqual(
            join(self.root, 'basin_forcing', 'basin_forcing_1mo_201612.nc'),
            self.ws.forcing(yearmon='201612', window=1, basis=Basis.BASIN)
        )

        # Forecast data
        self.assertEqual(
            join(self.root, 'forcing', 'forcing_1mo_201612_trgt201703_fcstcfsv1_13.nc'),
            self.ws.forcing(yearmon='201612', target='201703', model='CFSv1', member='13', window=1)
        )
        
    def test_results(self):
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
            join(self.root, 'results', 'results_1mo_201612_trgt201703_fcstcfsv1_13.nc'),
            self.ws.results(yearmon='201612', window=1, target='201703', model='CFSv1', member='13')
        )

        self.assertEqual(
            join(self.root, 'results_integrated', 'results_36mo_201612_trgt201703_fcstcfsv1_13.nc'),
            self.ws.results(yearmon='201612', target='201703', member='13', model='CFSv1', window=36)
        )

    def test_return_period(self):
        # Observed data
        self.assertEqual(
            join(self.root, 'pe3_1980_2009', 'rp', 'rp_1mo_201612.nc'),
            self.ws.return_period(yearmon='201612', window=1)
        )
        self.assertEqual(
            join(self.root, 'rp', 'rp_1mo_201612.nc'),
            self.ws_flat.return_period(yearmon='201612', window=1)
        )

        # Observed data
        self.assertEqual(
            join(self.root, 'pe3_1980_2009', 'rp_integrated', 'rp_24mo_201612.nc'),
            self.ws.return_period(yearmon='201612', window=24)
        )

        # Observed data (basins)
        self.assertEqual(
            join(self.root, 'pe3_1980_2009', 'basin_rp', 'basin_rp_1mo_201612.nc'),
            self.ws.return_period(yearmon='201612', window=1, basis=Basis.BASIN)
        )

        # Observed data (basins)
        self.assertEqual(
            join(self.root, 'pe3_1980_2009', 'basin_rp_integrated', 'basin_rp_24mo_201612.nc'),
            self.ws.return_period(yearmon='201612', window=24, basis=Basis.BASIN)
        )

        # Forecast data
        self.assertEqual(
            join(self.root, 'pe3_1980_2009', 'rp', 'rp_1mo_201612_trgt201703_fcstcfsv2_13.nc'),
            self.ws.return_period(yearmon='201612', target='201703', model='CFSv2', member='13', window=1)
        )

        self.assertEqual(
            join(self.root, 'pe3_1980_2009', 'rp_integrated', 'rp_36mo_201612_trgt201703_fcstcancm4i_6.nc'),
            self.ws.return_period(yearmon='201612', target='201703', model='CanCM4i', member='6', window=36)
        )

    def test_composite_anomaly(self):
        # Observed data
        self.assertEqual(
            join(self.root, 'pe3_1980_2009', 'composite_anom', 'composite_anom_1mo_201612.nc'),
            self.ws.composite_anomaly(yearmon='201612', window=1)
        )

        self.assertEqual(
            join(self.root, 'pe3_1980_2009', 'composite_anom', 'composite_anom_36mo_201612.nc'),
            self.ws.composite_anomaly(yearmon='201612', window=36)
        )

        # Forecast data
        self.assertEqual(
            join(self.root, 'pe3_1980_2009', 'composite_anom', 'composite_anom_1mo_201612_trgt201708.nc'),
            self.ws.composite_anomaly(yearmon='201612', target='201708', window=1)
        )

        self.assertEqual(
            join(self.root, 'pe3_1980_2009', 'composite_anom', 'composite_anom_6mo_201612_trgt201708.nc'),
            self.ws.composite_anomaly(yearmon='201612', target='201708', window=6)
        )

    def test_composite_anomaly_return_period(self):
        # Observed data
        self.assertEqual(
            join(self.root, 'pe3_1980_2009', 'composite_anom_rp', 'composite_anom_rp_1mo_201612.nc'),
            self.ws.composite_anomaly_return_period(yearmon='201612', window=1)
        )

        self.assertEqual(
            join(self.root, 'pe3_1980_2009', 'composite_anom_rp', 'composite_anom_rp_36mo_201612.nc'),
            self.ws.composite_anomaly_return_period(yearmon='201612', window=36)
        )

        # Forecast data
        self.assertEqual(
            join(self.root, 'pe3_1980_2009', 'composite_anom_rp', 'composite_anom_rp_1mo_201612_trgt201708.nc'),
            self.ws.composite_anomaly_return_period(yearmon='201612', target='201708', window=1)
        )

        self.assertEqual(
            join(self.root, 'pe3_1980_2009', 'composite_anom_rp', 'composite_anom_rp_6mo_201612_trgt201708.nc'),
            self.ws.composite_anomaly_return_period(yearmon='201612', target='201708', window=6)
        )

    def test_composite_summary(self):
        # Observed data
        self.assertEqual(
            join(self.root, 'pe3_1980_2009', 'composite', 'composite_1mo_201612.nc'),
            self.ws.composite_summary(yearmon='201612', window=1)
        )

        self.assertEqual(
            join(self.root, 'pe3_1980_2009', 'composite', 'composite_36mo_201612.nc'),
            self.ws.composite_summary(yearmon='201612', window=36)
        )

        # Forecast data
        self.assertEqual(
            join(self.root, 'pe3_1980_2009', 'composite', 'composite_1mo_201612_trgt201708.nc'),
            self.ws.composite_summary(yearmon='201612', target='201708', window=1)
        )

        self.assertEqual(
            join(self.root, 'pe3_1980_2009', 'composite', 'composite_6mo_201612_trgt201708.nc'),
            self.ws.composite_summary(yearmon='201612', target='201708', window=6)
        )

    def test_composite_summary_adjusted(self):
        # Observed data
        self.assertEqual(
            join(self.root, 'pe3_1980_2009', 'composite_adjusted', 'composite_adjusted_1mo_201612.nc'),
            self.ws.composite_summary_adjusted(yearmon='201612', window=1)
        )

        self.assertEqual(
            join(self.root, 'pe3_1980_2009', 'composite_adjusted', 'composite_adjusted_36mo_201612.nc'),
            self.ws.composite_summary_adjusted(yearmon='201612', window=36)
        )

        # Forecast data
        self.assertEqual(
            join(self.root, 'pe3_1980_2009', 'composite_adjusted', 'composite_adjusted_1mo_201612_trgt201708.nc'),
            self.ws.composite_summary_adjusted(yearmon='201612', target='201708', window=1)
        )

        self.assertEqual(
            join(self.root, 'pe3_1980_2009', 'composite_adjusted', 'composite_adjusted_6mo_201612_trgt201708.nc'),
            self.ws.composite_summary_adjusted(yearmon='201612', target='201708', window=6)
        )

    def test_return_period_summary(self):
        # Forecast data
        self.assertEqual(
            join(self.root, 'pe3_1980_2009', 'rp_summary', 'rp_summary_1mo_201612_trgt201708.nc'),
            self.ws.return_period_summary(yearmon='201612', target='201708', window=1)
        )

        self.assertEqual(
            join(self.root, 'pe3_1980_2009', 'rp_integrated_summary', 'rp_summary_6mo_201612_trgt201708.nc'),
            self.ws.return_period_summary(yearmon='201612', target='201708', window=6)
        )

    def test_results_summary(self):
        # Forecast data
        self.assertEqual(
            join(self.root, 'results_summary', 'results_summary_1mo_201612_trgt201708.nc'),
            self.ws.results_summary(yearmon='201612', target='201708', window=1)
        )

        self.assertEqual(
            join(self.root, 'results_integrated_summary', 'results_summary_6mo_201612_trgt201708.nc'),
            self.ws.results_summary(yearmon='201612', target='201708', window=6)
        )

    def test_standard_anomaly(self):
        self.assertEqual(
            join(self.root, 'pe3_1980_2009', 'anom', 'anom_1mo_201612_trgt201708_fcstcfsv2_XYZ.nc'),
            self.ws.standard_anomaly(yearmon='201612', target='201708', model='CFSv2', member='XYZ', window=1)
        )

        self.assertEqual(
            join(self.root, 'pe3_1980_2009', 'anom_integrated', 'anom_13mo_201612_trgt201708_fcstcfsv2_XYZ.nc'),
            self.ws.standard_anomaly(yearmon='201612', target='201708', model='CFSv2', member='XYZ', window=13)
        )

    def test_standard_anomaly_summary(self):
        self.assertEqual(
            join(self.root, 'pe3_1980_2009', 'anom_summary', 'anom_summary_1mo_201612_trgt201708.nc'),
            self.ws.standard_anomaly_summary(yearmon='201612', target='201708', window=1)
        )

        self.assertEqual(
            join(self.root, 'pe3_1980_2009', 'anom_integrated_summary', 'anom_summary_13mo_201612_trgt201708.nc'),
            self.ws.standard_anomaly_summary(yearmon='201612', target='201708', window=13)
        )

    def test_forcing_summary(self):
        self.assertEqual(
            join(self.root, 'forcing_summary', 'forcing_summary_1mo_201612_trgt201708.nc'),
            self.ws.forcing_summary(yearmon='201612', target='201708', window=1)
        )

    def test_fit_obs(self):
        self.assertEqual(
            join(self.root, 'pe3_1980_2009', 'fits', 'E_sum_6mo_month_04.nc'),
            self.ws.fit_obs(var='E', month=4, window=6, stat='sum')
        )
        self.assertEqual(
            join(self.root, 'fits', 'E_sum_6mo_month_04.nc'),
            self.ws_flat.fit_obs(var='E', month=4, window=6, stat='sum')
        )

        self.assertEqual(
            join(self.root, 'pe3_1980_2009', 'fits', 'T_1mo_month_04.nc'),
            self.ws.fit_obs(var='T', month=4, window=1)
        )

        self.assertEqual(
            join(self.root, 'pe3_1980_2009', 'fits', 'Bt_RO_sum_3mo_annual_min.nc'),
            self.ws.fit_obs(var='Bt_RO', stat='sum', window=3, annual_stat='min')
        )

        self.assertEqual(
            join(self.root, 'pe3_1980_2009', 'fits', 'basin_Bt_RO_sum_6mo_month_12.nc'),
            self.ws.fit_obs(var='Bt_RO', stat='sum', window=6, month=12, basis=Basis.BASIN)
        )

        with self.assertRaises(AssertionError):
            self.ws.fit_obs(var='Bt_RO', stat='sum', window=3)  # no month, and no annual stat

        with self.assertRaises(AssertionError):
            # can't have month for an annual stat
            self.ws.fit_obs(var='Bt_RO', stat='sum', window=3, annual_stat='min', month=4)

    def test_results_annual(self):
        self.assertEqual(
            join(self.root, 'basin_results_annual', 'basin_results_1mo_1950.nc'),
            self.ws.results(year=1950, window=1, basis=Basis.BASIN)
        )

        self.assertEqual(
            join(self.root, 'results_integrated_annual', 'results_3mo_1950.nc'),
            self.ws.results(year=1950, window=3)
        )

        with self.assertRaises(AssertionError):
            # Can't have an annual summary with a 24-month integration period
            self.ws.results(year=1950, window=24)

    def test_nonsensical_requests_caught(self):
        # Forecast data must have either a member or be summary
        with self.assertRaises(AssertionError):
            self.ws.make_path('results', yearmon='201801', target='201804')

        # Can't summarize when member is specified
        with self.assertRaises(AssertionError):
            self.ws.make_path('results', yearmon='201801', target='201804', member='abc', summary=True)
