# Copyright (c) 2018-2020 ISciences, LLC.
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

from wsim_workflow import actions, dates, grids, paths
from wsim_workflow.paths import Vardef
from wsim_workflow.step import Step
from wsim_workflow.data_sources import cpc_daily_precipitation, ghcn_cams, precl


class GHCN_CAMS_PRECL(paths.ObservedForcing):

    def __init__(self, source):
        self.source = source

    def name(self) -> str:
        return 'GHCN_CAMS_PRECL'

    def grid(self) -> grids.Grid:
        return grids.GLOBAL_HALF_DEGREE

    def temp_monthly(self, *, yearmon: str) -> paths.Vardef:
        year, _ = dates.parse_yearmon(yearmon)

        return paths.Vardef(os.path.join(self.source, 'GHCN_CAMS', str(year), 'ghcn_cams_{yearmon}.nc'.format(yearmon=yearmon)), 'T')

    def precip_monthly(self, *, yearmon: str) -> paths.Vardef:
        year, _ = dates.parse_yearmon(yearmon)

        return paths.Vardef(os.path.join(self.source, 'PRECL', str(year), 'precl_{yearmon}.nc'.format(yearmon=yearmon)),
                            'Pr')

    def p_wetdays(self, *, yearmon: str) -> paths.Vardef:
        year, month = dates.parse_yearmon(yearmon)

        if year < 1979:
            return self.mean_p_wetdays(month)
        else:
            return paths.Vardef(os.path.join(self.source,
                                             'NCEP',
                                             'wetdays',
                                             'wetdays_{yearmon}.nc'.format(yearmon=yearmon)),
                                'pWetDays')

    def mean_p_wetdays(self, month: int) -> Vardef:
        return paths.Vardef(os.path.join(self.source,
                                         'NCEP',
                                         'wetdays_ltmean',
                                         'wetdays_ltmean_month_{month:02d}.nc'.format(month=month)),
                            'pWetDays')

    def ghcn_cams_grib(self) -> str:
        return os.path.join(self.source, 'GHCN_CAMS', ghcn_cams.GHCN_CAMS_GRIB)

    def global_prep_steps(self) -> List[Step]:
        return \
            ghcn_cams.download_ghcn_cams(self.ghcn_cams_grib()) + \
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

        # Extract netCDF of monthly temperature from full binary file
        steps += ghcn_cams.extract_monthly_temperature(grib_file=self.ghcn_cams_grib(),
                                                       output_filename=self.temp_monthly(yearmon=yearmon).file,
                                                       yearmon=yearmon)
        steps += precl.download_precl(yearmon=yearmon,
                                      output_filename=self.precip_monthly(yearmon=yearmon).file)

        if year >= 1979:
            steps += cpc_daily_precipitation.download_monthly_precipitation(
                yearmon=yearmon,
                workdir=os.path.join(self.source,
                                     'NCEP',
                                     'daily_precip'),
                wetdays_fname=self.p_wetdays(yearmon=yearmon).file)

        return steps
