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

from forcing.era5 import ERA5
from forcing.climate_norm import ClimateNormForecast
from static.era5_static import ERA5Static


class ERA5ClimateNormForecastConfig(ConfigBase):

    def __init__(self, source, derived):
        self._observed = ERA5(source)
        self._forecast = {'climate_norm': ClimateNormForecast(source, derived, self._observed, 1980, 2009)}
        self._static = ERA5Static(source, self._observed.grid())
        self._workspace = paths.DefaultWorkspace(derived)

    def historical_years(self):
        return range(1950, 2021)

    def result_fit_years(self):
        return range(1952, 2012)

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


config = ERA5ClimateNormForecastConfig
