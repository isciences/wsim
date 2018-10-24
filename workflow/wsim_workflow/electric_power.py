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

import os

from typing import Iterable

from . import actions

from .commands import wsim_integrate, wsim_fit
from .dates import all_months, format_yearmon, available_yearmon_range
from .spinup import time_integrate_results
from .step import Step
from .paths import date_range, read_vars, DefaultWorkspace, Static, Vardef


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

    # Compute annual min flows, for sub-annual integration periods
    for window in [1] + config.integration_windows():
        if window < 12:
            for year in config.result_fit_years():
                integration_step = wsim_integrate(stats='min',
                                   inputs=read_vars(config.workspace().results(
                                       yearmon=available_yearmon_range(window=window, start_year=year, end_year=year),
                                       window=window,
                                       basis='basin'),
                                       'Bt_RO' if window == 1 else 'Bt_RO_sum'
                                   ),
                                   output=config.workspace().results(
                                       year=year,
                                       window=window,
                                       basis='basin'
                                   )).replace_dependencies(config.workspace().tag('basin_spinup_{}mo_results'.format(window)))
                steps.append(integration_step)


    # Compute fits of annual min flows
    for window in [1] + config.integration_windows():
        var_to_fit = 'Bt_RO_min' if window == 1 else 'Bt_RO_sum_min'

        if window < 12:
            #first_year, last_year = config.result_fit_years()[0, -1]

            #start_date = format_yearmon(first_year, window)
            #last_date = format_yearmon()

            steps.append(
                wsim_fit(
                    distribution=config.distribution,
                    inputs=read_vars(config.workspace().results(
                        year=date_range(config.result_fit_years()[0],
                                        config.result_fit_years()[-1]),
                        window=window,
                        basis='basin',
                    ), var_to_fit),
                    output=config.workspace().fit_obs(
                        basis='basin',
                        var='Bt_RO',
                        stat='sum' if window > 1 else None,
                        window=window,
                        annual_stat='min',
                    ),
                    window=window
                )
            )

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
            steps += actions.time_integrate(config.workspace(), config.lsm_integrated_stats(basis='basin'), yearmon=yearmon, window=window, basis='basin')

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

        # Compute basin-level losses
        steps += compute_basin_losses(config.workspace(), static=config.static_data(), yearmon=yearmon)

    return steps


def wsim_basin_losses(*,
                      basin_windows: str,
                      basin_stress: str,
                      bt_ro: Iterable[Vardef],
                      bt_ro_fits: Iterable[str],
                      output: str):
    cmd = [
        os.path.join('{BINDIR}', 'wsim_basin_losses.R'),
        '--windows', basin_windows,
        '--stress',  basin_stress,
        '--output',  output
    ]

    for vardef in bt_ro:
        cmd += ['--bt_ro', "{}".format(vardef)]

    for filename in bt_ro_fits:
        cmd += ['--bt_ro_fit', filename]

    return cmd


def compute_basin_losses(workspace: DefaultWorkspace,
                         *,
                         static: Static,
                         yearmon: str):

    bt_ro = []
    bt_ro_fits = []

    windows = (1, 3, 6, 12, 24, 36)

    for w in windows:
        bt_ro.append(Vardef(workspace.results(basis='basin', yearmon=yearmon, window=w),
                            'Bt_RO' if w == 1 else 'Bt_RO_sum'))

        # For integration periods < 12 months, use the distribution of annual minimum N-month sums.
        # For integration periods >= 12 months, just use the N-month sum ending in December.
        bt_ro_fits.append(workspace.fit_obs(basis='basin',
                                            var='Bt_RO',
                                            stat='sum' if w != 1 else None,
                                            window=w,
                                            annual_stat='min' if w < 12 else None,
                                            month=12 if w >= 12 else None))

    outfile = 'PLACEHOLDER_BASIN_LOSS'

    return [
        Step(
            targets=[outfile],
            dependencies=[v.file for v in bt_ro] + bt_ro_fits,
            commands=[
                wsim_basin_losses(
                    basin_windows='PLACEHOLDER_BASIN_WINDOWS',
                    basin_stress='PLACEHOLDER_BASIN_STRESS',
                    bt_ro=bt_ro,
                    bt_ro_fits=bt_ro_fits,
                    output=outfile
                )
            ]
        )
    ]
