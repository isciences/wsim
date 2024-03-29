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

from typing import List, Optional

from wsim_workflow import dates
from wsim_workflow import paths
from wsim_workflow.config_base import ConfigBase

from forcing.leaky_bucket import LeakyBucket
from forcing.nmme import NMMEForecast
from forcing.cfsv2 import CFSForecast
from static.default_static import DefaultStatic


class NMMEConfig(ConfigBase):

    def __init__(self, source, derived):
        self._observed = LeakyBucket(source)
        self._forecast = {
            'CFSv2':  CFSForecast(source, derived, self._observed),
            'CanCM4i': NMMEForecast(source, derived, self._observed, 'CanCM4i', 1982, 2010)
        }
        self._static = DefaultStatic(source, self._observed.grid())
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
            return CFSForecast.last_7_days_of_previous_month(yearmon, lag_hours)

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
