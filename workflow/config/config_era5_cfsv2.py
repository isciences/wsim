# Copyright (c) 2021 ISciences, LLC.
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

from wsim_workflow import dates
from wsim_workflow import paths

from wsim_workflow.config_base import ConfigBase

from forcing.era5 import ERA5
from forcing.cfsv2 import CFSForecast
from static.era5_static import ERA5Static


class ERA5CFSv2Config(ConfigBase):

    def __init__(self,
                 source,
                 derived,
                 *,
                 baseline_start_year: Optional[int] = None,
                 baseline_stop_year: Optional[int] = None,
                 integration_windows: Optional[int] = None,
                 distribution_subdir: Optional[bool] = True):
        self.set_fit_years(baseline_start_year, baseline_stop_year)
        self.set_integration_windows(integration_windows)

        fit_start, *_, fit_end = self.result_fit_years()
        self._observed = ERA5(source)
        self._forecast = {'CFSv2': CFSForecast(source, derived, self._observed)}
        self._static = ERA5Static(source, self._observed.grid())
        self._workspace = paths.DefaultWorkspace(derived,
                                                 distribution_subdir=distribution_subdir,
                                                 distribution=self.distribution,
                                                 fit_start_year=fit_start,
                                                 fit_end_year=fit_end)

    def land_mask(self) -> paths.Vardef:
        return self._observed.land_mask()

    def historical_years(self):
        return range(1950, 2021)  # 1950-2021

    def result_fit_years(self):
        return range(1952, 2012)  # 1952-2011

    def models(self):
        return ['CFSv2']

    def forecast_ensemble_members(self, model, yearmon, *, lag_hours: Optional[int] = None):
        assert model in self.models()

        return CFSForecast.last_7_days_of_previous_month(yearmon, lag_hours)

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


config = ERA5CFSv2Config
