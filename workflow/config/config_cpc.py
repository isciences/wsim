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

from typing import Iterable, List, Optional

from wsim_workflow.config_base import ConfigBase
from wsim_workflow import dates

import wsim_workflow.paths as paths


from forcing.cfsv2 import CFSForecast
from forcing.cpc_global_daily import CPCGlobalDaily
from static.default_static import DefaultStatic


class CPCConfig(ConfigBase):
    def __init__(self, source, derived):
        fit_start, *_, fit_end = self.result_fit_years()

        self._observed = CPCGlobalDaily(source)
        self._forecast = {
            'CFSv2':  CFSForecast(source, derived, self._observed),
        }
        self._static = DefaultStatic(source, self._observed.grid())
        self._workspace = paths.DefaultWorkspace(derived,
                                                 distribution=self.distribution,
                                                 fit_start_year=fit_start,
                                                 fit_end_year=fit_end)

    def result_fit_years(self) -> Iterable[int]:
        return range(1981, 2019)

    def static_data(self):
        return self._static

    def workspace(self) -> paths.DefaultWorkspace:
        return self._workspace

    def forecast_data(self, model: str) -> paths.ForecastForcing:
        return self._forecast[model]

    def observed_data(self) -> paths.ObservedForcing:
        return self._observed

    def historical_years(self):
        return range(1979, 2019)  # 1979 to 2018

    def models(self):
        return self._forecast.keys()

    def forecast_ensemble_members(self, model: str, yearmon: str, *, lag_hours: Optional[int] = None) -> List[str]:
        assert model == 'CFSv2'

        return CFSForecast.last_7_days_of_previous_month(yearmon, lag_hours)

    def forecast_targets(self, yearmon):
        return dates.get_next_yearmons(yearmon, 9)


config = CPCConfig
