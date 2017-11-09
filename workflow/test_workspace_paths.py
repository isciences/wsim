import unittest
from os.path import join
from paths import DefaultWorkspace

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
            join(self.root, 'results', 'results_201612.nc'),
            self.ws.results(yearmon='201612')
        )

        # Observed data
        self.assertEqual(
            join(self.root, 'results', 'results_24mo_201612.nc'),
            self.ws.results(yearmon='201612', window=24)
        )

        # Forecast data
        self.assertEqual(
            join(self.root, 'results', 'results_201612_trgt201703_fcstCFS13.nc'),
            self.ws.results(yearmon='201612', target='201703', member='CFS13')
        )

        self.assertEqual(
            join(self.root, 'results', 'results_36mo_201612_trgt201703_fcstCFS13.nc'),
            self.ws.results(yearmon='201612', target='201703', member='CFS13', window=36)
        )

    def testReturnPeriod(self):
        # Observed data
        self.assertEqual(
            join(self.root, 'rp', 'rp_201612.nc'),
            self.ws.return_period(yearmon='201612')
        )

        # Observed data
        self.assertEqual(
            join(self.root, 'rp', 'rp_24mo_201612.nc'),
            self.ws.return_period(yearmon='201612', window=24)
        )

        # Forecast data
        self.assertEqual(
            join(self.root, 'rp', 'rp_201612_trgt201703_fcstCFS13.nc'),
            self.ws.return_period(yearmon='201612', target='201703', member='CFS13')
        )

        self.assertEqual(
            join(self.root, 'rp', 'rp_36mo_201612_trgt201703_fcstCFS13.nc'),
            self.ws.return_period(yearmon='201612', target='201703', member='CFS13', window=36)
        )

    def testCompositeSummary(self):

        # Observed data
        self.assertEqual(
            join(self.root, 'composite', 'composite_201612.nc'),
            self.ws.composite_summary(yearmon='201612')
        )

        self.assertEqual(
            join(self.root, 'composite', 'composite_36mo_201612.nc'),
            self.ws.composite_summary(yearmon='201612', window=36)
        )

        # Forecast data
        self.assertEqual(
            join(self.root, 'composite', 'composite_201612_trgt201708.nc'),
            self.ws.composite_summary(yearmon='201612', target='201708')
        )

        self.assertEqual(
            join(self.root, 'composite', 'composite_6mo_201612_trgt201708.nc'),
            self.ws.composite_summary(yearmon='201612', target='201708', window=6)
        )

    def testReturnPeriodSummary(self):

        # Observed data
        self.assertEqual(
            join(self.root, 'rp_summary', 'rp_summary_201612.nc'),
            self.ws.return_period_summary(yearmon='201612')
        )

        self.assertEqual(
            join(self.root, 'rp_summary', 'rp_summary_36mo_201612.nc'),
            self.ws.return_period_summary(yearmon='201612', window=36)
        )

        # Forecast data
        self.assertEqual(
            join(self.root, 'rp_summary', 'rp_summary_201612_trgt201708.nc'),
            self.ws.return_period_summary(yearmon='201612', target='201708')
        )

        self.assertEqual(
            join(self.root, 'rp_summary', 'rp_summary_6mo_201612_trgt201708.nc'),
            self.ws.return_period_summary(yearmon='201612', target='201708', window=6)
        )

    def testResultsSummary(self):

        # Observed data
        self.assertEqual(
            join(self.root, 'results_summary', 'results_summary_201612.nc'),
            self.ws.results_summary(yearmon='201612')
        )

        self.assertEqual(
            join(self.root, 'results_summary', 'results_summary_36mo_201612.nc'),
            self.ws.results_summary(yearmon='201612', window=36)
        )

        # Forecast data
        self.assertEqual(
            join(self.root, 'results_summary', 'results_summary_201612_trgt201708.nc'),
            self.ws.results_summary(yearmon='201612', target='201708')
        )

        self.assertEqual(
            join(self.root, 'results_summary', 'results_summary_6mo_201612_trgt201708.nc'),
            self.ws.results_summary(yearmon='201612', target='201708', window=6)
        )
