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


import os

from typing import List

from wsim_workflow import actions, dates, paths
from wsim_workflow.paths import Vardef
from wsim_workflow.grids import Grid
from wsim_workflow.step import Step
from wsim_workflow.data_sources import era5


class ERA5(paths.ObservedForcing):

    def __init__(self, source):
        self.source = source

    def name(self) -> str:
        return 'ERA5'

    def grid(self) -> Grid:
        return Grid('ERA5_quarter_degree', -179.875, -90.125, 180.125, 90.125, 1440, 721)

    def temp_monthly(self, *, yearmon: str) -> paths.Vardef:
        return paths.Vardef(era5.filename(self.source, 'month', yearmon), 't2m')

    def precip_monthly(self, *, yearmon: str) -> paths.Vardef:
        return paths.Vardef(era5.filename(self.source, 'month', yearmon), 'tp')

    def p_wetdays(self, *, yearmon: str) -> paths.Vardef:
        year, month = dates.parse_yearmon(yearmon)

        if year < 1979:
            return self.mean_p_wetdays(month)
        else:
            return paths.Vardef(os.path.join(self.source,
                                             'ERA5',
                                             'wetdays',
                                             'wetdays_{yearmon}.nc'.format(yearmon=yearmon)),
                                'pWetDays')

    def mean_p_wetdays(self, month: int) -> Vardef:
        return paths.Vardef(os.path.join(self.source,
                                         'ERA5',
                                         'wetdays_ltmean',
                                         'wetdays_ltmean_month_{month:02d}.nc'.format(month=month)),
                            'pWetDays')

    def global_prep_steps(self) -> List[Step]:
        return \
            actions.compute_wetday_ltmeans(self, 1979, 2008)

    def prep_steps(self, *, yearmon: str) -> List[Step]:
        """
        Prep steps are data preparation tasks that are executed once per model iteration.
        They may include downloading, unpackaging, aggregation, or conversion of data inputs.

        :param yearmon: yearmon of model iteration
        :return: a list of Steps
        """
        steps = []

        year, month = dates.parse_yearmon(yearmon)

        monthly_vars = ['2m_temperature', 'total_precipitation']
        hourly_vars = ['total_precipitation']

        steps += era5.download(output_filename=era5.filename(self.source, 'month', yearmon),
                               duration='month',
                               yearmon=yearmon,
                               variables=monthly_vars)

        if year >= 1979:
            steps += era5.download(output_filename=era5.filename(self.source, 'hour', yearmon),
                                   duration='hour',
                                   yearmon=yearmon,
                                   variables=hourly_vars)
            steps += era5.calc_wetdays(input_filename=era5.filename(self.source, 'hour', yearmon),
                                       output_filename=self.p_wetdays(yearmon=yearmon).file,
                                       threshold_mm=0.1)

        return steps
