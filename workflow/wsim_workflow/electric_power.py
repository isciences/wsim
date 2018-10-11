# Copyright (c) 2018 ISciences, LLC.
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

from . import actions

from .commands import wsim_integrate
from .dates import all_months, format_yearmon
from .spinup import time_integrate_results
from .step import Step
from .paths import date_range, read_vars

def spinup(config, meta_steps):
    steps = []
    all_fits = meta_steps['all_fits']

    b2b_steps = []
    for yearmon in config.historical_yearmons():
        b2b_steps += actions.run_b2b(workspace=config.workspace(),
                                     static=config.static_data(),
                                     yearmon=yearmon)

    steps += b2b_steps

    steps.append(Step(
        targets=config.workspace().tag('basin_spinup_1mo_results'),
        dependencies=[config.workspace().results(yearmon=yearmon, window=1, basis='basin') for yearmon in config.historical_yearmons()]
    ))

    # Time-integrate the variables
    for window in config.integration_windows():
        steps += time_integrate_results(config, window, basis='basin')

    # Compute monthly fits over the fit period
    for param in config.lsm_rp_vars(basis='basin') + config.forcing_rp_vars(basis='basin'):
        for month in all_months:
            steps += all_fits.require(actions.fit_var(config, param=param, month=month, basis='basin'))

    # Compute time-integrated fits
    for window in config.integration_windows():
        for param in config.lsm_integrated_var_names(basis='basin'):
            for month in all_months:
                steps += all_fits.require(actions.fit_var(config, param=param, window=window, month=month, basis='basin'))

    # Compute annual min flows, for subannual intergration periods
    for window in [1] + config.integration_windows():
        if window < 12:
            for year in config.result_fit_years():
                steps += [
                    wsim_integrate(stats='min',
                                   inputs=read_vars(config.workspace().results(
                                       yearmon=date_range(format_yearmon(year, all_months[0]),
                                                          format_yearmon(year, all_months[-1])),
                                       window=window,
                                       basis='basin'),
                                       'Bt_RO' if window == 1 else 'Bt_RO_sum'
                                   ),
                                   output=config.workspace().results(
                                       year=year,
                                       window=window,
                                       basis='basin'
                                   ))

                ]

    return steps


def monthly_observed(config, yearmon, meta_steps):
    print('Generating electric power steps for', yearmon, 'observed data')

    steps = []

    # Skip if we would already have run this date as part of spinup
    if yearmon not in config.historical_yearmons():
        if config.should_run_lsm(yearmon):
            steps += actions.run_b2b(workspace=config.workspace(),
                                     static=config.static_data(),
                                     yearmon=yearmon)

    if yearmon not in config.result_fit_yearmons():
        # Do time integration
        for window in config.integration_windows():
            steps += actions.time_integrate(config.workspace(), { 'sum' : 'Bt_RO' }, yearmon=yearmon, window=window, basis='basin')

        # Compute return periods
        steps += actions.compute_return_periods(config.workspace(),
                                                result_vars=config.lsm_rp_vars(basis='basin'),
                                                yearmon=yearmon,
                                                window=1,
                                                basis='basin')

        for window in config.integration_windows():
            steps += actions.compute_return_periods(config.workspace(),
                                                    result_vars=config.lsm_integrated_var_names(basis='basin'),
                                                    yearmon=yearmon,
                                                    window=window,
                                                    basis='basin')

    return steps

