# Copyright (c) 2020-2021 ISciences, LLC.
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

from typing import Optional

from wsim_workflow.config_base import ConfigBase
from wsim_workflow import dates
from wsim_workflow import paths

from forcing.ghcn_cams_precl import GHCN_CAMS_PRECL
from forcing.climate_norm import ClimateNormForecast
from static.default_static import DefaultStatic


class ClimateNormForecastConfig(ConfigBase):

    def __init__(self,
                 source,
                 derived,
                 *,
                 baseline_start_year: Optional[int] = None,
                 baseline_stop_year: Optional[int] = None,
                 integration_windows: Optional[int] = None):
        self.set_fit_years(baseline_start_year, baseline_stop_year)
        self.set_integration_windows(integration_windows)

        fit_start, *_, fit_end = self.result_fit_years()

        self._observed = GHCN_CAMS_PRECL(source)
        self._forecast = {'climate_norm': ClimateNormForecast(source, derived, self._observed, 1980, 2009)}
        self._static = DefaultStatic(source, self._observed.grid())
        self._workspace = paths.DefaultWorkspace(derived,
                                                 distribution=self.distribution,
                                                 fit_start_year=fit_start,
                                                 fit_end_year=fit_end)

    def historical_years(self):
        return range(1948, 2018)  # 1948-2017

    def result_fit_years(self):
        return range(1950, 2010)  # 1950-2009

    def models(self):
        return self._forecast.keys()

    def forecast_ensemble_members(self, model, yearmon, *, lag_hours: Optional[int] = None):
        assert model in self.models()

        return '1'

    def forecast_targets(self, yearmon):
        return dates.get_next_yearmons(yearmon, 9)

    def forecast_data(self, model: str):
        return self._forecast[model]

    def observed_data(self):
        return self._observed

    def static_data(self):
        return self._static

    def workspace(self) -> paths.DefaultWorkspace:
        return self._workspace


config = ClimateNormForecastConfig
