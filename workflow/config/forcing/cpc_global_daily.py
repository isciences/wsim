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

from wsim_workflow import actions, paths, grids
from wsim_workflow.step import Step

from wsim_workflow.data_sources import cpc_daily_temperature, cpc_daily_precipitation


class CPCGlobalDaily(paths.ObservedForcing):

    def __init__(self, source):
        self.source = source

        self.temp_workdir = os.path.join(self.source, 'CPC_Global_Daily_Temperature', 'raw')
        self.precip_workdir = os.path.join(self.source, 'CPC_Global_Daily_Precipitation', 'raw')

    def name(self) -> str:
        return 'CPC_Global_Daily'

    def grid(self) -> grids.Grid:
        return grids.GLOBAL_HALF_DEGREE

    def prep_steps(self, *, yearmon: str) -> List[Step]:
        return \
            cpc_daily_temperature.download_monthly_temperature(
                yearmon=yearmon,
                workdir=self.temp_workdir,
                output_filename=self.temp_monthly(yearmon=yearmon).file) + \
            cpc_daily_precipitation.download_monthly_precipitation(
                yearmon=yearmon,
                workdir=self.precip_workdir,
                precipitation_fname=self.precip_monthly(yearmon=yearmon).file,
                wetdays_fname=self.p_wetdays(yearmon=yearmon).file)

    def global_prep_steps(self) -> List[Step]:
        return actions.compute_wetday_ltmeans(self, 1979, 2018)

    def precip_monthly(self, *, yearmon: str) -> paths.Vardef:
        return paths.Vardef(os.path.join(self.source,
                                         'CPC_Global_Daily_Precipitation',
                                         'monthly_sum',
                                         'P_{}.nc'.format(yearmon)),
                            'Pr')

    def temp_monthly(self, *, yearmon: str) -> paths.Vardef:
        return paths.Vardef(os.path.join(self.source,
                                         'CPC_Global_Daily_Temperature',
                                         'monthly_mean',
                                         'T_{}.nc'.format(yearmon)),
                            'tavg')

    def p_wetdays(self, *, yearmon: str) -> paths.Vardef:
        return paths.Vardef(os.path.join(self.source,
                                         'CPC_Global_Daily_Precipitation',
                                         'monthly_wetdays',
                                         'pWetDays_{}.nc'.format(yearmon)),
                            'pWetDays')

    def mean_p_wetdays(self, month: int) -> paths.Vardef:
        return paths.Vardef(os.path.join(self.source,
                                         'CPC_Global_Daily_Precipitation',
                                         'monthly_wetdays_mean',
                                         'mean_pWetDays_month_{:02d}.nc'.format(month)),
                            'pWetDays')
