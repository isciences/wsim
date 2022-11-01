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

from wsim_workflow import dates, paths, grids
from wsim_workflow.paths import Vardef, ObservedForcing

from wsim_workflow.commands import wsim_integrate


class PerfectForecast(paths.ForecastForcing):

    def __init__(self, observed: paths.ObservedForcing):
        self._observed = observed

    def name(self) -> str:
        return 'perfect_forecast_' + self._observed.name()

    def grid(self) -> grids.Grid:
        return self._observed.grid()

    @staticmethod
    def requires_bias_correction() -> bool:
        return False

    def temp_monthly(self, *, yearmon: str, target: str, member: str) -> Vardef:
        return self._observed.temp_monthly(yearmon=target)

    def p_wetdays(self, *, yearmon: str, target: str, member: str) -> Vardef:
        return self._observed.p_wetdays(yearmon=target)

    def precip_monthly(self, *, yearmon: str, target: str, member: str) -> Vardef:
        return self._observed.precip_monthly(yearmon=target)

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
