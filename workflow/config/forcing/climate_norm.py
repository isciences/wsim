# Copyright (c) 2020 ISciences, LLC.
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

from wsim_workflow import dates, paths
from wsim_workflow.paths import Vardef, ObservedForcing

from wsim_workflow.commands import wsim_integrate


class ClimateNormForecast(paths.ForecastForcing):

    def __init__(self, source: str,
                 derived: str,
                 observed: paths.ObservedForcing,
                 min_year: int,
                 max_year: int):
        self.source = source
        self.derived = derived,
        self._observed = observed
        self.min_year = min_year
        self.max_year = max_year

    @staticmethod
    def requires_bias_correction() -> bool:
        return False

    def global_prep_steps(self):
        steps = []

        dummy_yearmon = '000000'
        dummy_member = '1'

        for month in dates.all_months:
            yearmons = [dates.format_yearmon(y, month) for y in range(self.min_year, self.max_year + 1)]
            dummy_target = dates.format_yearmon(0000, month)

            steps.append(wsim_integrate(
                inputs=[self.observed().precip_monthly(yearmon=x).read_as('Pr') for x in yearmons],
                output=self.precip_monthly(yearmon=dummy_yearmon, target=dummy_target, member=dummy_member).file,
                stats='ave',
                keepvarnames=True
            ))

            steps.append(wsim_integrate(
                inputs=[self.observed().temp_monthly(yearmon=x).read_as('T') for x in yearmons],
                output=self.temp_monthly(yearmon=dummy_yearmon, target=dummy_target, member=dummy_member).file,
                stats='ave',
                keepvarnames=True
            ))

            steps.append(wsim_integrate(
                inputs=[self.observed().p_wetdays(yearmon=x).read_as('pWetDays') for x in yearmons],
                output=self.p_wetdays(yearmon=dummy_yearmon, target=dummy_target, member=dummy_member).file,
                stats='ave',
                keepvarnames=True
            ))

        return steps

    def subdir(self):
        return os.path.join(self.source, 'climate_norms_{}_{}'.format(self.min_year, self.max_year))

    def temp_monthly(self, *, yearmon: str, target: str, member: str) -> Vardef:
        _, month = dates.parse_yearmon(target)

        return paths.Vardef(
            os.path.join(self.subdir(), 'mean_temperature_month_{:02d}.nc'.format(month)),
            'T')

    def p_wetdays(self, *, yearmon: str, target: str, member: str) -> Vardef:
        _, month = dates.parse_yearmon(target)

        return paths.Vardef(
            os.path.join(self.subdir(), 'mean_p_wetdays_month_{:02d}.nc'.format(month)),
            'pWetDays')

    def precip_monthly(self, *, yearmon: str, target: str, member: str) -> Vardef:
        _, month = dates.parse_yearmon(target)

        return paths.Vardef(
            os.path.join(self.subdir(), 'mean_prate_month_{:02d}.nc'.format(month)),
            'Pr')

    def fit_obs(self, *, var, month):
        assert False

    def fit_retro(self, *, var, target_month, lead_months):
        assert False

    def forecast_raw(self, *, yearmon: str, target: str, member: str):
        assert False

    def forecast_corrected(self, *, yearmon: str, target: str, member: str):
        assert False

    def observed(self) -> ObservedForcing:
        return self._observed
