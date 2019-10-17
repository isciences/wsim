# Copyright (c) 2019 ISciences, LLC.
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

# This configuration file is provided as an example of an automated operational WSIM workflow.

import datetime
import os

from typing import List, Optional

from wsim_workflow import actions
from wsim_workflow import commands
from wsim_workflow import dates
from wsim_workflow import paths

from wsim_workflow.config_base import ConfigBase
from wsim_workflow.step import Step

from config_cfs import CFSStatic, CFSForecast, NCEP

NOAA_RTA_VARIABLES = ('tmp2m', 'prate')
WSIM_FORCING_VARIABLES = ('T', 'Pr')
NOAA_RTA_FTP_ROOT = 'ftp://ftp.cpc.ncep.noaa.gov/NMME'


class NMMEForecast(paths.ForecastForcing):

    def __init__(self,
                 source: str,
                 derived: str,
                 observed: paths.ObservedForcing,
                 model_name: str,
                 min_hindcast_year: int,
                 max_hindcast_year: int):
        self.source = source
        self.derived = derived
        self.observed = observed
        self.model_name = model_name
        self.min_hindcast_year = min_hindcast_year
        self.max_hindcast_year = max_hindcast_year

    def model_dir(self):
        return os.path.join(self.source, 'NMME', self.model_name)

    def temp_monthly(self, *, yearmon, target, member):
        return paths.Vardef(self.forecast_corrected(yearmon=yearmon, target=target, member=member), 'T')

    def precip_monthly(self, *, yearmon, target, member):
        return paths.Vardef(self.forecast_corrected(yearmon=yearmon, target=target, member=member), 'Pr')

    def p_wetdays(self, *, yearmon=None, target, member=None):
        month = int(target[4:])

        return paths.Vardef(os.path.join(self.source,
                                         'NCEP',
                                         'wetdays_ltmean',
                                         'wetdays_ltmean_month_{month:02d}.nc'.format(month=month)),
                            'pWetDays')

    def fit_obs(self, *, var, month):
        assert var in WSIM_FORCING_VARIABLES

        return os.path.join(self.model_dir(),
                            'hindcast_fits',
                            '{model}_obs_{var}_month_{month:02d}.nc'.format(model=self.model_name,
                                                                            var=var,
                                                                            month=month))

    def fit_retro(self, *, var, target_month, lead_months):
        assert var in WSIM_FORCING_VARIABLES

        return os.path.join(self.model_dir(),
                            'hindcast_fits',
                            '{model}_retro_{var}_month_{target_month:02d}_lead_{lead_months:d}.nc'.format(
                                model=self.model_name,
                                var=var,
                                target_month=target_month,
                                lead_months=lead_months))

    def forecast_clim(self, *, varname: str, month: int) -> str:
        assert varname in NOAA_RTA_VARIABLES

        return os.path.join(self.model_dir(),
                            'clim',
                            '{model}.{varname}.{month:02d}.mon.clim.nc'.format(model=self.model_name,
                                                                               varname=varname,
                                                                               month=month))

    def forecast_raw(self, *, yearmon: str, target: str, member: str):
        return os.path.join(self.model_dir(),
                            'raw_sci',
                            yearmon,
                            '{model}_{yearmon}_trgt{target}_fcst{member}.nc'.format(model=self.model_name,
                                                                                    yearmon=yearmon,
                                                                                    target=target,
                                                                                    member=member))

    def forecast_anom(self, *, yearmon: str, varname: str) -> str:
        assert varname in NOAA_RTA_VARIABLES

        return os.path.join(self.model_dir(),
                            'raw_anom',
                            yearmon,
                            '{model}.{varname}.{yearmon}.anom.nc'.format(model=self.model_name,
                                                                         varname=varname,
                                                                         yearmon=yearmon))

    def forecast_corrected(self, *, yearmon: str, target: str, member: int):
        return os.path.join(self.model_dir(),
                            'corrected',
                            yearmon,
                            'nmme_{model}_{yearmon}_trgt{target}_fcst{model}_{member}_corrected.nc'.format(
                                model=self.model_name,
                                target=target,
                                yearmon=yearmon,
                                member=member
                            ))

    def download_hindcasts(self):
        steps = []

        iri_url = 'http://iridl.ldeo.columbia.edu/SOURCES/.Models/.NMME/.{model}/.HINDCAST/.MONTHLY/.{varname}/dods'

        hindcast_dir = os.path.join(self.model_dir(), 'hindcasts')

        for varname in ('prec', 'tref'):
            fname = os.path.join(hindcast_dir, '{model}_{varname}_hindcasts.nc'.format(model=self.model_name,
                                                                                       varname=varname))
            steps.append(Step(
                targets=fname,
                dependencies=[],
                commands=[
                    [
                        'nccopy',
                        '-7',       # netCDF-4 classic
                        '-d', '1',  # level-1 deflate,
                        iri_url.format(model=self.model_name, varname=varname),
                        fname
                    ]
                ]
            ))

        return steps

    def compute_fit_obs(self, varname: str, month: int) -> List[Step]:
        assert varname in WSIM_FORCING_VARIABLES

        # For simplicity, we want to compare all forecasts to a consistent set of observed data.
        # In other words, we don't want to compare March lead-6 forecasts to observed data
        # from March 1983-March 2011 and March lead-2 forecasts to observed data from March 1982-March 2010.
        # So we restrict the range of dates.

        start = dates.format_yearmon(self.min_hindcast_year + 1, month)
        stop = dates.format_yearmon(self.max_hindcast_year - 1, month)

        rng = dates.format_range(start, stop, 12)

        if varname == 'Pr':
            inputs = self.observed.precip_monthly(yearmon=rng)
        if varname == 'T':
            inputs = self.observed.temp_monthly(yearmon=rng)

        return [
            commands.wsim_fit(distribution='gev',
                              inputs=[inputs],
                              output=self.fit_obs(var=varname, month=month),
                              window=1)
        ]

    def fit_hindcast(self, varname: str, month: int, lead: int):
        pass

    def download_realtime_anomaly_climatologies(self):
        steps = []

        # Download climatologies from NOAA. There is one file per forecast variable/forecast generation month
        for month in range(1, 13):
            for varname in NOAA_RTA_VARIABLES:
                clim_path = self.forecast_clim(varname=varname, month=month)
                clim_dirname = os.path.dirname(clim_path)
                clim_fname = os.path.basename(clim_path)
                clim_url = '{root}/clim/{fname}'.format(root=NOAA_RTA_FTP_ROOT, fname=clim_fname)

                steps.append(
                    commands.download(clim_url, clim_dirname)
                )

        return steps

    def download_realtime_anomalies(self, yearmon: str):
        steps = []

        # Download forecasts from NOAA. There is one file per forecast variable/forecast generation month
        for varname in NOAA_RTA_VARIABLES:
            anom_path = self.forecast_anom(yearmon=yearmon, varname=varname)
            anom_dirname = os.path.dirname(anom_path)
            anom_fname = os.path.basename(anom_path)
            anom_url = '{root}/realtime_anom/{model}/{yearmon}0800/{fname}'.format(
                root=NOAA_RTA_FTP_ROOT,
                model=self.model_name,
                yearmon=yearmon,
                fname=anom_fname
            )

            steps.append(commands.download(anom_url, anom_dirname))

        return steps

    def global_prep_steps(self):
        steps = []

        steps += self.download_hindcasts()
        steps += self.download_realtime_anomaly_climatologies()

        for month in dates.all_months:
            for var in WSIM_FORCING_VARIABLES:
                steps += self.compute_fit_obs(varname=var, month=month)

        # FIXME: add steps for fitting hindcast distributions

        return steps

    def prep_steps(self, *, yearmon: str, target: str, member: str) -> List[Step]:
        steps = []

        _, month = dates.parse_yearmon(yearmon)

        # Hack to only download these once although they are required for
        # all members / forecast targets
        if int(member) == 1 and target == dates.add_months(yearmon, 1):
            steps += self.download_realtime_anomalies(yearmon)

        steps.append(Step(
            targets=self.forecast_raw(yearmon=yearmon, target=target, member=member),
            dependencies=[self.forecast_anom(yearmon=yearmon, varname='tmp2m'),
                          self.forecast_anom(yearmon=yearmon, varname='prate'),
                          self.forecast_clim(month=month, varname='tmp2m'),
                          self.forecast_clim(month=month, varname='prate')],
            commands=[
                [
                    '{BINDIR}/utils/nmme/extract_nmme_forecast.R',
                    '--clim_precip', self.forecast_clim(month=month, varname='prate'),
                    '--clim_temp',   self.forecast_clim(month=month, varname='tmp2m'),
                    '--anom_precip', self.forecast_anom(yearmon=yearmon, varname='prate'),
                    '--anom_temp',   self.forecast_anom(yearmon=yearmon, varname='tmp2m'),
                    '--member', member,
                    '--lead', str(dates.get_lead_months(yearmon, target)),
                    '--output', self.forecast_raw(yearmon=yearmon, target=target, member=member)
                ]
            ]))

        return steps


class NMMEConfig(ConfigBase):

    def __init__(self, source, derived):
        self._observed = NCEP(source)
        self._forecast = {
            'CFSv2':  CFSForecast(source, derived),
            'CanCM4i': NMMEForecast(source, derived, self._observed, 'CanCM4i', 1982, 2010)
        }
        self._static = CFSStatic(source)
        self._workspace = paths.DefaultWorkspace(derived)

    def historical_years(self):
        return range(1948, 2018)  # 1948-2017

    def result_fit_years(self):
        return range(1950, 2010)  # 1950-2009

    def models(self):
        return self._forecast.keys()

    def forecast_ensemble_members(self, model: str, yearmon: str, *, lag_hours: Optional[int] = None) -> List[str]:
        assert model in self.models()

        if model == 'CFSv2':
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

        if model == 'CanCM4i':
            return [str(i) for i in range(1, 11)]

    def forecast_targets(self, yearmon):
        return dates.get_next_yearmons(yearmon, 9)

    def forecast_data(self, model):
        return self._forecast[model]

    def observed_data(self):
        return self._observed

    def static_data(self):
        return self._static

    def workspace(self) -> paths.DefaultWorkspace:
        return self._workspace


config = NMMEConfig
