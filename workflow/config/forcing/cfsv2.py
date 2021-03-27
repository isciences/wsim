# Copyright (c) 2018-2021 ISciences, LLC.
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

import datetime
import os

from typing import List, Optional

from wsim_workflow import actions, commands, dates, paths
from wsim_workflow.step import Step

WSIM_FORCING_VARIABLES = ('T', 'Pr')

HINDCAST_DATES_FOR_MONTH = [
    None,
    [1, 6, 11, 16, 26, 31],   # January
    [5, 10, 15, 20, 25],      # February
    [2, 7, 12, 17, 22, 27],   # March
    [1, 6, 11, 16, 26],       # April
    [1, 6, 11, 16, 26, 31],   # May
    [5, 10, 15, 20, 25, 30],  # June
    [5, 10, 15, 20, 25, 30],  # July
    [4, 9, 14, 19, 24, 29],   # August
    [3, 8, 13, 18, 23, 28],   # September
    [3, 8, 13, 18, 23, 28],   # October
    [2, 7, 12, 17, 22, 27],   # November
    [2, 7, 12, 17, 22, 27],   # December
]

MISSING_HINDCASTS = {
    '1985092306': {'198602'},
    '1986011618': {'198606'},
    '1986040612': {'198606', '198609'},
    '1986081400': {'198701'},
    '1987072000': {'198804'},
    '1987080906': {'198709'},
    '1987091306': {'198710', '198804'},
    '1987101312': {'198801'},
    '1988011612': {'198802'},
    '1988021000': {'198810'},
    '1988122212': {'198905'},
    '1989021500': {'198903', '198905', '198909'},
    '1989061000': {'198908'},
    '1989070500': {'198908'},
    '1989100818': {'199004'},
    '2004010118': {'200406'},
}

CORRUPT_HINDCASTS = {
    '1984092800': {'198504'}
}


class CFSForecast(paths.ForecastForcing):

    def __init__(self, source: str, derived: str, observed: paths.ObservedForcing):
        self.source = source
        self.derived = derived,
        self._observed = observed
        self.min_fit_year = 1983   # although we have hindcasts generated in 1982, we don't have
                                   # all month/lead time combinations until 1983.
        self.max_fit_year = 2009
        self.hindcast_distribution = 'gev'

    def name(self) -> str:
        return 'CFSv2'

    def observed(self) -> paths.ObservedForcing:
        return self._observed

    def temp_monthly(self, *, yearmon: str, target: str, member: str) -> paths.Vardef:
        return paths.Vardef(self.forecast_corrected(yearmon=yearmon, target=target, member=member), 'T')

    def precip_monthly(self, *, yearmon: str, target: str, member: str) -> paths.Vardef:
        return paths.Vardef(self.forecast_corrected(yearmon=yearmon, target=target, member=member), 'Pr')

    def p_wetdays(self, *, yearmon=None, target, member=None) -> paths.Vardef:
        _, month = dates.parse_yearmon(target)
        return self.observed().mean_p_wetdays(month=month)

    def fit_obs(self, *, var: str, month: int) -> str:
        return os.path.join(self.source,
                            'NCEP_CFSv2',
                            'hindcast_fits',
                            self._observed.name(),
                            'obs_{var}_month_{month:02d}.nc'.format(var=var, month=month))

    def fit_retro(self, *, var: str, target_month: int, lead_months: int) -> str:
        return os.path.join(self.source,
                            'NCEP_CFSv2',
                            'hindcast_fits',
                            self._observed.grid().name,
                            'retro_{var}_month_{target_month:02d}_lead_{lead_months:d}.nc'.format(var=var,
                                                                                                  target_month=target_month,  # noqa
                                                                                                  lead_months=lead_months))   # noqa

    def forecast_raw(self, *, yearmon: str, target: str, member: str) -> str:
        return os.path.join(self.source,
                            'NCEP_CFSv2',
                            'raw_nc',
                            self._observed.grid().name,
                            member[:6],
                            'cfs_trgt{target}_fcst{member}_raw.nc'.format(target=target, member=member))

    def hindcast_raw(self, *, timestamp: str, target: str) -> str:
        return os.path.join(self.source,
                            'NCEP_CFSv2',
                            'hindcast_nc',
                            self._observed.grid().name,
                            timestamp[:6],
                            'cfs_trgt{target}_fcst{timestamp}_raw.nc').format(target=target, timestamp=timestamp)

    def forecast_corrected(self, *, yearmon: str, target: str, member: str) -> str:
        return os.path.join(self.source,
                            'NCEP_CFSv2',
                            'corrected',
                            self._observed.name(),
                            'cfs_trgt{target}_fcst{member}_corrected.nc'.format(target=target, member=member))

    def grib_dir(self, *, timestamp: str) -> str:
        return os.path.join(self.source,
                            'NCEP_CFSv2',
                            'raw_grib',
                            'cfs.{}'.format(timestamp[:-2]))

    def hindcast_grib(self, *, timestamp: str, target: str) -> str:
        return os.path.join(self.source,
                            'NCEP_CFSv2',
                            'hindcast_grib',
                            'cfs.{}'.format(timestamp[:-2]),
                            'flxf{}.01.{}.avrg.grb2'.format(timestamp, target))

    def forecast_grib(self, *, timestamp: str, target: str) -> str:
        return os.path.join(self.grib_dir(timestamp=timestamp),
                            'flxf.01.{member}.{target}.avrg.grib.grb2'.format(member=timestamp, target=target))

    def global_prep_steps(self) -> List[Step]:
        steps = []

        for month in dates.all_months:
            # Compute these using our local data
            for var in WSIM_FORCING_VARIABLES:
                steps += actions.compute_observed_forcing_fit_for_hindcast_period(self,
                                                                                  varname=var,
                                                                                  min_fit_year=self.min_fit_year,
                                                                                  max_fit_year=self.max_fit_year,
                                                                                  month=month,
                                                                                  distribution=self.hindcast_distribution)

            for lead in range(1, 10):
                steps += self.download_hindcasts(month, lead)

                for var in WSIM_FORCING_VARIABLES:
                    steps += self.compute_fit_hindcast(var, month, lead)

        return steps

    def available_hindcasts(self, target_month: int, lead: int) -> List[str]:
        forecast_month = target_month - lead
        if forecast_month < 1:
            forecast_month += 12

        for forecast_year in range(self.min_fit_year - 1, self.max_fit_year + 1):
            target = dates.add_months(dates.format_yearmon(forecast_year, forecast_month), lead)
            target_year, _ = dates.parse_yearmon(target)

            if target_year > self.max_fit_year:
                continue

            assert dates.parse_yearmon(target)[1] == target_month

            for day in HINDCAST_DATES_FOR_MONTH[forecast_month]:
                for hour in (0, 6, 12, 18):
                    timestamp = '{:04d}{:02d}{:02d}{:02d}'.format(forecast_year, forecast_month, day, hour)

                    if timestamp in MISSING_HINDCASTS and target in MISSING_HINDCASTS[timestamp]:
                        continue

                    if timestamp in CORRUPT_HINDCASTS and target in CORRUPT_HINDCASTS[timestamp]:
                        continue

                    yield timestamp, target

    def download_hindcasts(self, target_month: int, lead: int) -> List[Step]:
        steps = []

        for timestamp, target in self.available_hindcasts(target_month, lead):
            grib_file = self.hindcast_grib(timestamp=timestamp, target=target)
            grib_dir = os.path.dirname(grib_file)

            netcdf_file = self.hindcast_raw(timestamp=timestamp, target=target)

            steps.append(Step(
                targets=grib_file,
                dependencies=[],
                commands=[
                    [
                        os.path.join('{BINDIR}', 'utils', 'noaa_cfsv2_forecast', 'download_cfsv2_forecast.py'),
                        '--timestamp', timestamp,
                        '--target', target,
                        '--output_dir', grib_dir
                    ]
                ]
            ))

            steps.append(commands.forecast_convert(grib_file, netcdf_file, self.observed().grid()))

        return steps

    def compute_fit_hindcast(self, varname: str, target_month: int, lead: int) -> List[Step]:
        assert varname in {'T', 'Pr'}

        inputs = [str(paths.Vardef(self.hindcast_raw(timestamp=timestamp, target=target), varname))
                  for timestamp, target in self.available_hindcasts(target_month, lead)]

        return [
            commands.wsim_fit(
                distribution='gev',
                inputs=inputs,
                output=self.fit_retro(var=varname, target_month=target_month, lead_months=lead),
                window=1
            )
        ]

    def prep_steps(self, *, yearmon: str, target: str, member: str) -> List[Step]:
        outfile = self.forecast_raw(yearmon=yearmon, member=member, target=target).split('::')[0]
        infile = self.forecast_grib(timestamp=member, target=target)

        return [
            # Download the GRIB, if needed
            Step(
                targets=self.forecast_grib(timestamp=member, target=target),
                dependencies=[],
                commands=[
                    [
                        os.path.join('{BINDIR}', 'utils', 'noaa_cfsv2_forecast', 'download_cfsv2_forecast.py'),
                        '--timestamp', member,
                        '--target', target,
                        '--output_dir', self.grib_dir(timestamp=member)
                    ]
                ]

            ),
            # Convert the forecast data from GRIB to netCDF
            commands.forecast_convert(infile, outfile, self.observed().grid())
        ]

    @staticmethod
    def last_7_days_of_previous_month(yearmon: str, lag_hours: Optional[int] = None) -> List[str]:
        # Build an ensemble of 28 forecasts by taking the four
        # forecasts issued on each of the last 7 days of the month.
        last_day = dates.get_last_day_of_month(yearmon)

        year, month = dates.parse_yearmon(yearmon)

        members = [datetime.datetime(year, month, day, hour)
                   for day in range(last_day - 6, last_day + 1)
                   for hour in (0, 6, 12, 18)]

        if lag_hours is not None:
            members = [m for m in members if datetime.datetime.utcnow() - m > datetime.timedelta(hours=lag_hours)]

        return [m.strftime('%Y%m%d%H') for m in members]
