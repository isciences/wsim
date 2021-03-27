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

import os

from typing import List

from wsim_workflow import actions, commands, dates, paths
from wsim_workflow.commands import q
from wsim_workflow.step import Step

IRI_VARS = {'T': 'tref', 'Pr': 'prec'}
NOAA_RTA_FTP_ROOT = 'ftp://ftp.cpc.ncep.noaa.gov/NMME'
NOAA_RTA_VARS = {'T': 'tmp2m', 'Pr': 'prate'}
WSIM_FORCING_VARIABLES = ('T', 'Pr')


def wsim_to_nmme_yearmon(yearmon: str):
    return dates.add_months(yearmon, 1)


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
        self._observed = observed
        self.model_name = model_name
        self.min_hindcast_year = min_hindcast_year
        self.max_hindcast_year = max_hindcast_year
        self.hindcast_distribution = 'gev'

    def name(self) -> str:
        return 'NMME_' + self.model_name

    def observed(self) -> paths.ObservedForcing:
        return self._observed

    def global_prep_steps(self) -> List[Step]:
        steps = []

        steps += self.download_hindcasts()
        steps += self.download_realtime_anomaly_climatologies()

        for month in dates.all_months:
            for var in WSIM_FORCING_VARIABLES:
                # For simplicity, we want to compare all forecasts to a consistent set of observed data.
                # In other words, we don't want to compare March lead-6 forecasts to observed data
                # from March 1983-March 2011 and March lead-2 forecasts to observed data from March 1982-March 2010.
                # So we restrict the range of dates.
                steps += actions.compute_observed_forcing_fit_for_hindcast_period(self,
                                                                                  varname=var,
                                                                                  min_fit_year=self.min_hindcast_year+1,
                                                                                  max_fit_year=self.max_hindcast_year-1,
                                                                                  month=month,
                                                                                  distribution=self.hindcast_distribution)  # noqa

                for lead in range(1, 10):
                    steps += self.compute_fit_hindcast(var, month, lead)

        return steps

    def prep_steps(self, *, yearmon: str, target: str, member: str) -> List[Step]:
        steps = []

        _, nmme_month = dates.parse_yearmon(wsim_to_nmme_yearmon(yearmon))

        # Hack to only download these once although they are required for
        # all members / forecast targets
        if int(member) == 1 and target == dates.add_months(yearmon, 1):
            steps += self.download_realtime_anomalies(nmme_yearmon=wsim_to_nmme_yearmon(yearmon))

        output = self.forecast_raw(yearmon=yearmon, target=target, member=member).split('::')[0]

        steps.append(Step(
            targets=output,
            dependencies=[self.forecast_anom(nmme_yearmon=wsim_to_nmme_yearmon(yearmon), varname='T'),
                          self.forecast_anom(nmme_yearmon=wsim_to_nmme_yearmon(yearmon), varname='Pr'),
                          self.forecast_clim(nmme_month=nmme_month, varname='T'),
                          self.forecast_clim(nmme_month=nmme_month, varname='Pr')],
            commands=[
                [
                    os.path.join('{BINDIR}', 'utils', 'nmme', 'extract_nmme_forecast.R'),
                    '--clim_precip', self.forecast_clim(nmme_month=nmme_month, varname='Pr'),
                    '--clim_temp',   self.forecast_clim(nmme_month=nmme_month, varname='T'),
                    '--anom_precip', self.forecast_anom(nmme_yearmon=wsim_to_nmme_yearmon(yearmon), varname='Pr'),
                    '--anom_temp',   self.forecast_anom(nmme_yearmon=wsim_to_nmme_yearmon(yearmon), varname='T'),
                    '--member', member,
                    '--lead', str(dates.get_lead_months(wsim_to_nmme_yearmon(yearmon), target)),
                    '--output', output
                ]
            ]))

        return steps

    def model_dir(self) -> str:
        return os.path.join(self.source, 'NMME', self.model_name)

    def temp_monthly(self, *, yearmon: str, target: str, member: str) -> paths.Vardef:
        return paths.Vardef(self.forecast_corrected(yearmon=yearmon, target=target, member=member), 'T')

    def precip_monthly(self, *, yearmon: str, target: str, member: str) -> paths.Vardef:
        return paths.Vardef(self.forecast_corrected(yearmon=yearmon, target=target, member=member), 'Pr')

    def p_wetdays(self, *, yearmon=None, target, member=None):
        month = int(target[4:])

        return paths.Vardef(os.path.join(self.source,
                                         'NCEP',
                                         'wetdays_ltmean',
                                         'wetdays_ltmean_month_{month:02d}.nc'.format(month=month)),
                            'pWetDays')

    def fit_obs(self, *, var: str, month: int) -> str:
        assert var in WSIM_FORCING_VARIABLES

        return os.path.join(self.model_dir(),
                            'hindcast_fits',
                            '{model}_obs_{var}_month_{month:02d}.nc'.format(model=self.model_name.lower(),
                                                                            var=var,
                                                                            month=month))

    def fit_retro(self, *, var: str, target_month: int, lead_months: int) -> str:
        assert var in WSIM_FORCING_VARIABLES

        return os.path.join(self.model_dir(),
                            'hindcast_fits',
                            '{model}_retro_{var}_month_{target_month:02d}_lead_{lead_months:d}.nc'.format(
                                model=self.model_name.lower(),
                                var=var,
                                target_month=target_month,
                                lead_months=lead_months))

    def forecast_clim(self, *, varname: str, nmme_month: int) -> str:
        assert varname in WSIM_FORCING_VARIABLES

        return os.path.join(self.model_dir(),
                            'clim',
                            '{model}.{varname}.{month:02d}.mon.clim.nc'.format(model=self.model_name,
                                                                               varname=NOAA_RTA_VARS[varname],
                                                                               month=nmme_month))

    def forecast_raw(self, *, yearmon: str, target: str, member: str):
        return os.path.join(self.model_dir(),
                            'raw_sci',
                            yearmon,
                            '{model}_{yearmon}_trgt{target}_fcst{member}.nc'.format(model=self.model_name.lower(),
                                                                                    yearmon=yearmon,
                                                                                    target=target,
                                                                                    member=member))

    def forecast_anom(self, *, nmme_yearmon: str, varname: str) -> str:
        assert varname in WSIM_FORCING_VARIABLES

        return os.path.join(self.model_dir(),
                            'raw_anom',
                            'nmme_{}'.format(nmme_yearmon),
                            '{model}.{varname}.{yearmon}.anom.nc'.format(model=self.model_name,
                                                                         varname=NOAA_RTA_VARS[varname],
                                                                         yearmon=nmme_yearmon))

    def forecast_corrected(self, *, yearmon: str, target: str, member: str):
        return os.path.join(self.model_dir(),
                            'corrected',
                            yearmon,
                            'nmme_{model}_{yearmon}_trgt{target}_fcst{model}_{member}_corrected.nc'.format(
                                model=self.model_name.lower(),
                                target=target,
                                yearmon=yearmon,
                                member=member
                            ))

    def hindcast(self, varname: str) -> str:
        assert varname in WSIM_FORCING_VARIABLES

        hindcast_dir = os.path.join(self.model_dir(), 'hindcasts')
        return os.path.join(hindcast_dir,
                            '{model}_{varname}_hindcasts.nc'.format(model=self.model_name.lower(),
                                                                    varname=IRI_VARS[varname]))

    def download_hindcasts(self):
        steps = []

        iri_url = 'http://iridl.ldeo.columbia.edu/SOURCES/.Models/.NMME/.{model}/.HINDCAST/.MONTHLY/.{varname}/dods'

        for varname in WSIM_FORCING_VARIABLES:
            steps.append(Step(
                targets=self.hindcast(varname),
                dependencies=[],
                commands=[
                    [
                        'nccopy',
                        '-7',       # netCDF-4 classic
                        '-d', '1',  # level-1 deflate,
                        q(iri_url.format(model=self.model_name, varname=IRI_VARS[varname])),
                        self.hindcast(varname)
                    ]
                ]
            ))

        return steps

    def compute_fit_hindcast(self, varname: str, month: int, lead: int) -> List[Step]:
        assert varname in WSIM_FORCING_VARIABLES

        start = self.min_hindcast_year + 1
        stop = self.max_hindcast_year - 1

        # The lead months will be computed by WSIM, based on the difference between
        # the WSIM data version and target month. Since the NMME forecast reference
        # time is one month greater than the WSIM data version, the hindcast fits
        # at an N-month lead need to be computed from NMME data with an (N-1)-month
        # lead.
        #
        # As an example, a WSIM workflow generated for data version 201901 will
        # will request a corrected NMME forecast targeting 201904, which it will
        # consider to be a 3-month lead time. The NMME forecast accessed by
        # WSIM data version 201901 will have an NMME reference time of 201902.
        # So for the context of the fit_nmme_hindcasts.R script, the raw
        # forecast will have a lead time of two months.

        output = self.fit_retro(var=varname, target_month=month, lead_months=lead)

        return [
            Step(
                targets=output,
                dependencies=self.hindcast(varname),
                commands=[
                    [
                        os.path.join('{BINDIR}', 'utils', 'nmme', 'fit_nmme_hindcasts.R'),
                        '--distribution', 'gev',
                        '--input',         self.hindcast(varname),
                        '--varname',       varname,
                        '--min_year',      str(start),
                        '--max_year',      str(stop),
                        '--target_month',  str(month),
                        '--output',        output,
                        '--lead',          str(lead - 1)  # <--- IMPORTANT! Subtract 1 from lead to account for
                        #      difference between WSIM data version / "yearmon"
                        #      and NMME forecast "reference time".
                    ]
                ]

            )
        ]

    def download_realtime_anomalies(self, *, nmme_yearmon: str) -> List[Step]:
        steps = []

        # Download forecasts from NOAA. There is one file per forecast variable/forecast generation month
        for varname in WSIM_FORCING_VARIABLES:
            anom_path = self.forecast_anom(nmme_yearmon=nmme_yearmon, varname=varname)
            anom_dirname = os.path.dirname(anom_path)
            anom_fname = os.path.basename(anom_path)
            anom_url = '{root}/realtime_anom/{model}/{nmme_yearmon}0800/{fname}'.format(
                root=NOAA_RTA_FTP_ROOT,
                model=self.model_name,
                nmme_yearmon=nmme_yearmon,
                fname=anom_fname
            )

            steps.append(commands.download(anom_url, anom_dirname))

        return steps

    def download_realtime_anomaly_climatologies(self) -> List[Step]:
        steps = []

        # Download climatologies from NOAA. There is one file per forecast variable/forecast generation month
        for nmme_month in range(1, 13):
            for varname in WSIM_FORCING_VARIABLES:
                clim_path = self.forecast_clim(varname=varname, nmme_month=nmme_month)
                clim_dirname = os.path.dirname(clim_path)
                clim_fname = os.path.basename(clim_path)
                clim_url = '{root}/clim/{fname}'.format(root=NOAA_RTA_FTP_ROOT, fname=clim_fname)

                steps.append(
                    commands.download(clim_url, clim_dirname)
                )

        return steps
