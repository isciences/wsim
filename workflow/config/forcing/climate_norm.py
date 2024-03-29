# Copyright (c) 2020-2022 ISciences, LLC.
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

from typing import List, Optional

from wsim_workflow import dates, paths
from wsim_workflow.grids import Grid
from wsim_workflow.paths import Vardef, ObservedForcing
from wsim_workflow.step import Step

from wsim_workflow.commands import wsim_integrate, wsim_quantile, wsim_fit


class ClimateNormForecast(paths.ForecastForcing):

    def __init__(self, source: str,
                 derived: str,
                 *,
                 observed: paths.ObservedForcing,
                 min_year: int,
                 max_year: int,
                 distribution: Optional[str] = None,
                 stat: str):
        self.source = source
        self.derived = derived,
        self._observed = observed
        self.min_year = min_year
        self.max_year = max_year
        self.stat = stat
        self.distribution = distribution


        if self.stat == 'mean':
            self.wsim_integrate_stat = 'ave'
        elif self.stat == 'median':
            self.wsim_integrate_stat = 'q50'
        else:
            raise Exception(f'Unknown stat: {self.stat}')

    def name(self) -> str:
        if self.distribution:
            return f'climate_norm_{self.distribution}_{self.stat}'
        else:
            return f'climate_norm_{self.stat}'

    def grid(self) -> Grid:
        return self._observed.grid()

    @staticmethod
    def requires_bias_correction() -> bool:
        return False

    def calculate_empirical_norms(self) -> List[Step]:
        steps = []

        dummy_yearmon = '000000'
        dummy_member = '1'

        for month in dates.all_months:
            yearmons = [dates.format_yearmon(y, month) for y in range(self.min_year, self.max_year + 1)]
            dummy_target = dates.format_yearmon(0000, month)

            steps.append(wsim_integrate(
                inputs=[self.observed().precip_monthly(yearmon=x).read_as('Pr') for x in yearmons],
                output=self.precip_monthly(yearmon=dummy_yearmon, target=dummy_target, member=dummy_member).file,
                stats=self.wsim_integrate_stat,
                keepvarnames=True
            ))

            steps.append(wsim_integrate(
                inputs=[self.observed().temp_monthly(yearmon=x).read_as('T') for x in yearmons],
                output=self.temp_monthly(yearmon=dummy_yearmon, target=dummy_target, member=dummy_member).file,
                stats=self.wsim_integrate_stat,
                keepvarnames=True
            ))

            steps.append(wsim_integrate(
                inputs=[self.observed().p_wetdays(yearmon=x).read_as('pWetDays') for x in yearmons],
                output=self.p_wetdays(yearmon=dummy_yearmon, target=dummy_target, member=dummy_member).file,
                stats=self.wsim_integrate_stat,
                keepvarnames=True
            ))

        return steps


    def calculate_parametric_norms(self) -> List[Step]:
        steps = []

        dummy_yearmon = '000000'
        dummy_member = '1'

        assert self.stat == 'median'

        for month in dates.all_months:
            yearmons = [dates.format_yearmon(y, month) for y in range(self.min_year, self.max_year + 1)]
            dummy_target = dates.format_yearmon(0000, month)

            steps.append(wsim_fit(
                inputs=[self.observed().temp_monthly(yearmon=x).read_as('T') for x in yearmons],
                output=self.fit('T', month),
                window=1,
                distribution=self.distribution
            ))

            steps.append(wsim_fit(
                inputs=[self.observed().p_wetdays(yearmon=x).read_as('pWetDays') for x in yearmons],
                output=self.fit('pWetDays', month),
                window=1,
                distribution=self.distribution
            ))

            steps.append(wsim_fit(
                inputs=[self.observed().precip_monthly(yearmon=x).read_as('Pr') for x in yearmons],
                output=self.fit('Pr', month),
                window=1,
                distribution=self.distribution
            ))

            steps.append(wsim_quantile(
                fits=self.fit('T', month),
                sa=0,
                output=self.temp_monthly(yearmon=dummy_yearmon, target=dummy_target, member=dummy_member).file,
                median_when_undefined=True
            ))

            steps.append(wsim_quantile(
                fits=self.fit('Pr', month),
                sa=0,
                output=self.precip_monthly(yearmon=dummy_yearmon, target=dummy_target, member=dummy_member).file,
                median_when_undefined=True
            ))

            steps.append(wsim_quantile(
                fits=self.fit('pWetDays', month),
                sa=0,
                output=self.p_wetdays(yearmon=dummy_yearmon, target=dummy_target, member=dummy_member).file,
                median_when_undefined=True
            ))

        return steps

    def global_prep_steps(self):
        if self.distribution:
            return self.calculate_parametric_norms()
        else:
            return self.calculate_empirical_norms()

    def subdir(self):
        return os.path.join(self.source,
                            'climate_norms',
                            self.observed().name(),
                            'climate_norms_{}_{}'.format(self.min_year, self.max_year))

    def fit(self, varname: str, month: int):
        return os.path.join(self.subdir(),
                            'fits',
                            self.distribution,
                            f'{varname}_month_{month}_{self.min_year}_{self.max_year}.nc')

    def fname_stem(self) -> str:
        if self.distribution:
            return f'{self.distribution}_{self.stat}'
        else:
            return self.stat

    def fname(self, varname: str, month: int) -> str:
        return f'{varname}_{self.fname_stem()}_month_{month:02d}.nc'

    def temp_monthly(self, *, yearmon: str, target: str, member: str) -> Vardef:
        _, month = dates.parse_yearmon(target)

        return paths.Vardef(
            os.path.join(self.subdir(), self.fname('T', month)),
            'T')

    def p_wetdays(self, *, yearmon: str, target: str, member: str) -> Vardef:
        _, month = dates.parse_yearmon(target)

        return paths.Vardef(
            os.path.join(self.subdir(), self.fname('pWetDays', month)),
            'pWetDays')

    def precip_monthly(self, *, yearmon: str, target: str, member: str) -> Vardef:
        _, month = dates.parse_yearmon(target)

        return paths.Vardef(
            os.path.join(self.subdir(), self.fname('Pr', month)),
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
