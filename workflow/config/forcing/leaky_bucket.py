# Copyright (c) 2018-2019 ISciences, LLC.
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
from wsim_workflow.step import Step


class LeakyBucket(paths.ObservedForcing):

    def __init__(self, source):
        self.source = source

    def temp_monthly(self, *, yearmon: str) -> paths.Vardef:
        return paths.Vardef(os.path.join(self.source, 'NCEP', 'T', 'T_{yearmon}.nc'.format(yearmon=yearmon)), 'T')

    def precip_monthly(self, *, yearmon: str) -> paths.Vardef:
        return paths.Vardef(os.path.join(self.source, 'NCEP', 'P', 'P_{yearmon}.nc'.format(yearmon=yearmon)), 'P')

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

    def global_prep_steps(self) -> List[Step]:
        return \
            self.download_monthly_temp_and_precip_files() + \
            actions.compute_wetday_ltmeans(self, 1979, 2008)

    def download_monthly_temp_and_precip_files(self) -> List[Step]:
        """
        Steps to download (or update) the t.long and p.long full data sets from NCEP.
        Because this is a single step (no matter which yearmon we're running), we can't
        include it in prep_steps below.
        """
        return [
            Step(
                targets=self.full_temp_file(),
                dependencies=[],
                commands=[
                    [
                        'wget', '--continue',
                        '--directory-prefix', os.path.join(self.source, 'NCEP'),
                        'ftp://ftp.cpc.ncep.noaa.gov/wd51yf/global_monthly/gridded_binary/t.long'
                    ]
                ]
            ),
            Step(
                targets=self.full_precip_file(),
                dependencies=[],
                commands=[
                    [
                        'wget', '--continue',
                        '--directory-prefix', os.path.join(self.source, 'NCEP'),
                        'ftp://ftp.cpc.ncep.noaa.gov/wd51yf/global_monthly/gridded_binary/p.long'
                    ]
                ]
            )
        ]

    def prep_steps(self, *, yearmon: str) -> List[Step]:
        """
        Prep steps are data preparation tasks that are executed once per model iteration.
        They may include downloading, unpackaging, aggregation, or conversion of data inputs.

        :param yearmon: yearmon of model iteration
        :return: a list of Steps
        """
        steps = []

        year, month = dates.parse_yearmon(yearmon)

        # Extract netCDF of monthly precipitation from full binary file
        steps.append(
            Step(
                targets=self.precip_monthly(yearmon=yearmon).file,
                dependencies=self.full_precip_file(),
                commands=[
                    [
                        os.path.join('{BINDIR}',
                                     'utils',
                                     'noaa_global_leaky_bucket',
                                     'read_binary_grid.R'),
                        '--input',   self.full_precip_file(),
                        '--update_url', 'ftp://ftp.cpc.ncep.noaa.gov/wd51yf/global_monthly/gridded_binary/p.long',
                        '--output',  self.precip_monthly(yearmon=yearmon).file,
                        '--var',     'P',
                        '--yearmon', yearmon,
                    ]
                ]
            )
        )

        # Extract netCDF of monthly temperature from full binary file
        steps.append(
            Step(
                targets=self.temp_monthly(yearmon=yearmon).file,
                dependencies=self.full_temp_file(),
                commands=[
                    [
                        os.path.join('{BINDIR}',
                                     'utils',
                                     'noaa_global_leaky_bucket',
                                     'read_binary_grid.R'),
                        '--input',   self.full_temp_file(),
                        '--update_url', 'ftp://ftp.cpc.ncep.noaa.gov/wd51yf/global_monthly/gridded_binary/t.long',
                        '--output',  self.temp_monthly(yearmon=yearmon).file,
                        '--var',     'T',
                        '--yearmon', yearmon
                    ]
                ]
            )
        )

        if year >= 1979:
            # FIXME call new code in data_sources and Delete compute_noaa_cpc_pwetdays.py

            # Download and process files in a single command
            # We do this to avoid including 365 files/year as
            # individual dependencies, clogging up the Makefile.
            #
            # If the precip files already exist, they won't be
            # re-downloaded.
            steps.append(
                Step(
                    targets=self.p_wetdays(yearmon=yearmon).file,
                    dependencies=[],
                    commands=[
                        [
                            os.path.join('{BINDIR}',
                                         'utils',
                                         'noaa_cpc_daily_precip',
                                         'download_noaa_cpc_daily_precip.py'),
                            '--yearmon', yearmon,
                            '--output_dir', os.path.join(self.source,
                                                         'NCEP',
                                                         'daily_precip')
                        ],
                        [
                            os.path.join('{BINDIR}',
                                         'utils',
                                         'noaa_cpc_daily_precip',
                                         'compute_noaa_cpc_pwetdays.py'),
                            '--bindir', '{BINDIR}',
                            '--yearmon', yearmon,
                            '--input_dir', os.path.join(self.source,
                                                        'NCEP',
                                                        'daily_precip'),
                            '--output_dir', os.path.join(self.source,
                                                         'NCEP',
                                                         'wetdays')
                        ]
                    ]
                )
            )

        return steps

    def full_temp_file(self) -> str:
        return os.path.join(self.source, 'NCEP', 't.long')

    def full_precip_file(self) -> str:
        return os.path.join(self.source, 'NCEP', 'p.long')
