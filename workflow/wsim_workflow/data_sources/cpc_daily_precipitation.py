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

import calendar
import os

from typing import List, Optional

from ..step import Step
from .. import commands
from .. import dates


def download_daily_precipitation(*, yearmon, workdir) -> Step:
    return Step(targets=[],
                dependencies=[],
                commands=[
                    [
                        os.path.join('{BINDIR}',
                                     'utils',
                                     'noaa_cpc_daily_precip',
                                     'download_noaa_cpc_daily_precip.py'),
                        '--yearmon', yearmon,
                        '--output_dir', workdir
                    ]
                ])


def input_files(*, workdir: str, yearmon: str) -> str:
    year, month = dates.parse_yearmon(yearmon)

    return os.path.join(workdir,
                        str(year),
                        'PRCP_CU_GAUGE_V1.0GLB_0.50deg.lnx.[{YEARMON}01:{YEARMON}{DAYS_IN_MONTH:02d}].gz'.format(YEARMON=yearmon,
                                                                                                                 DAYS_IN_MONTH=calendar.monthrange(year, month)[1]))


def compute_wetdays(*, yearmon: str, workdir: str, fname: str) -> Step:
    # TODO document use of [x-1] here to ignore trace precipitation
    step = commands.wsim_integrate(inputs=input_files(workdir=workdir, yearmon=yearmon) + '::1@[x-1]->pWetDays',
                                   stats='fraction_defined_above_zero',
                                   output=fname,
                                   keepvarnames=True)
    # Remove dependencies; they will be taken care of by merging this step with download_daily_precipitation()
    # This is done to avoid hundreds of dependencies per year.
    step.dependencies = set()
    return step


def compute_monthly_precipitation(*, yearmon: str, workdir: str, fname: str):
    year, month = dates.parse_yearmon(yearmon)
    days_in_month = calendar.monthrange(year, month)[1]
    seconds_in_month = days_in_month * 24 * 60 * 60

    # convert from 0.1mm daily totals to mm/s (kg/m^2/s)
    transformation = '[x*10/{}]'.format(seconds_in_month)

    step = commands.wsim_integrate(inputs=input_files(workdir=workdir, yearmon=yearmon) + '::1@{}->Pr'.format(transformation),
                                   stats='ave',
                                   output=fname,
                                   attrs=['Pr:units=kg/m^2/s', 'Pr:standard_name=precipitation_flux'],
                                   keepvarnames=True)
    # Remove dependencies; they will be taken care of by merging this step with download_daily_precipitation()
    # This is done to avoid hundreds of dependencies per year.
    step.dependencies = set()
    return step


def download_monthly_precipitation(*,
                                   yearmon,
                                   workdir,
                                   precipitation_fname: Optional[str] = None,
                                   wetdays_fname: Optional[str] = None) -> List[Step]:
    assert yearmon >= '197901'
    assert precipitation_fname or wetdays_fname

    step = download_daily_precipitation(yearmon=yearmon, workdir=workdir)
    if wetdays_fname:
        step = step.merge(compute_wetdays(yearmon=yearmon, workdir=workdir, fname=wetdays_fname))
    if precipitation_fname:
        step = step.merge(compute_monthly_precipitation(yearmon=yearmon, workdir=workdir, fname=precipitation_fname))

    return [step]
