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
import tempfile

from typing import Iterable, List, Mapping, Union, Optional

from . import actions, commands

from .dates import all_months, available_yearmon_range, parse_yearmon, get_lead_months
from .spinup import time_integrate_results
from .step import Step
from .paths import date_range, read_vars, DefaultWorkspace, ElectricityStatic, Vardef
from .config_base import ConfigBase

AGGREGATION_POLYGONS = ('basin', 'province', 'country')


def spinup(config: ConfigBase, meta_steps: Mapping[str, Step]) -> List[Step]:
    steps = []
    all_fits = meta_steps['all_fits']

    b2b_steps = []
    for yearmon in config.historical_yearmons():
        b2b_steps += actions.compute_basin_results(workspace=config.workspace(),
                                                   static=config.static_data(),
                                                   yearmon=yearmon)

    steps += b2b_steps

    steps.append(Step(
        targets=config.workspace().tag('basin_spinup_1mo_results'),
        dependencies=[config.workspace().results(yearmon=yearmon, window=1, basis='basin')
                      for yearmon in config.historical_yearmons()]
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
                steps += all_fits.require(
                    actions.fit_var(config, param=param, window=window, month=month, basis='basin'))

    # Compute annual min flows, for sub-annual integration periods
    for window in [1] + config.integration_windows():
        if window < 12:
            for year in config.result_fit_years():
                integration_step = commands.wsim_integrate(
                    stats='min',
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
            steps.append(
                commands.wsim_fit(
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

    # Compute upstream storage of each basin
    steps += compute_basin_integration_windows(config.workspace(), config.static_data())

    # Compute baseline water stress for each basin
    steps += compute_basin_water_stress(config.workspace(), config.static_data())

    # Prepare power-plant data
    steps += prepare_power_plants(config.workspace(), config.static_data())

    return steps


def monthly_observed(config: ConfigBase, yearmon: str, meta_steps: Mapping[str, Step]) -> List[Step]:
    print('Generating electric power steps for', yearmon, 'observed data')

    steps = []

    # Skip if we would already have run this date as part of spinup
    if yearmon not in config.historical_yearmons():
        if config.should_run_lsm(yearmon):
            steps += actions.compute_basin_results(workspace=config.workspace(),
                                                   static=config.static_data(),
                                                   yearmon=yearmon)

    if yearmon not in config.result_fit_yearmons():
        # Do time integration
        for window in config.integration_windows():
            steps += actions.time_integrate(config.workspace(),
                                            config.lsm_integrated_stats(basis='basin'),
                                            yearmon=yearmon,
                                            window=window,
                                            basis='basin')
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

        # Compute basin loss factors
        steps += compute_basin_loss_factors(config.workspace(), yearmon=yearmon)

        # Compute plant-level losses
        steps += compute_plant_losses(config.workspace(), yearmon=yearmon)

        # Compute aggregated losses
        for basis in AGGREGATION_POLYGONS:
            steps += meta_steps['electric_power_assessment'].require(
                compute_aggregated_losses(config.workspace(), yearmon=yearmon, basis=basis)
            )

    return steps


def monthly_forecast(config: ConfigBase, yearmon: str, meta_steps: Mapping[str, Step]) -> List[Step]:
    steps = []

    for target in config.forecast_targets(yearmon):
        print('Generating electric power steps for', yearmon, 'forecast target', target)
        for member in config.forecast_ensemble_members(yearmon):
            steps += actions.compute_basin_results(workspace=config.workspace(),
                                                   static=config.static_data(),
                                                   yearmon=yearmon,
                                                   target=target,
                                                   member=member)

            for window in config.integration_windows():
                steps += actions.time_integrate(config.workspace(),
                                                config.lsm_integrated_stats(basis='basin'),
                                                yearmon=yearmon,
                                                target=target,
                                                member=member,
                                                window=window,
                                                basis='basin')

            steps += compute_basin_loss_factors(config.workspace(), yearmon=yearmon, target=target, member=member)
            steps += compute_plant_losses(config.workspace(), yearmon=yearmon, target=target, member=member)

            for basis in AGGREGATION_POLYGONS:
                steps += compute_aggregated_losses(config.workspace(), yearmon=yearmon, basis=basis, target=target, member=member)

        for basis in AGGREGATION_POLYGONS:
            steps += meta_steps['electric_power_assessment'].require(
                compute_loss_summary(config.workspace(),
                                     ensemble_members=config.forecast_ensemble_members(yearmon),
                                     yearmon=yearmon,
                                     target=target,
                                     basis=basis))

    return steps


def compute_loss_summary(workspace: DefaultWorkspace,
                         ensemble_members: List[str], *,
                         yearmon: str,
                         target: str,
                         basis: str) -> List[Step]:

    loss_vars = ('gross_loss_mw',  'net_loss_mw',  'hydro_loss_mw',  'nuclear_loss_mw',
                 'gross_loss_pct', 'net_loss_pct', 'hydro_loss_pct', 'nuclear_loss_pct',
                 'reserve_utilization_pct')

    return [
        commands.wsim_integrate(
            inputs=[workspace.electric_loss_risk(
                yearmon=yearmon,
                target=target,
                member=member,
            basis=basis) for member in ensemble_members],
            stats=['q{}::{}'.format(q, ','.join(loss_vars)) for q in (25, 50, 75)],
            output=workspace.electric_loss_risk(yearmon=yearmon, target=target, basis=basis, summary=True)
        ),
    ]


def prepare_power_plants(workspace: DefaultWorkspace, static: ElectricityStatic) -> List[Step]:
    return [
        Step(
            targets=[workspace.power_plants()],
            dependencies=[
                static.power_plants(),
                static.countries().file,
                static.provinces().file,
                static.basins().file
            ],
            commands=[
                append_boundaries(
                    points=static.power_plants().file,
                    boundaries=[
                        static.countries().file + '::GID->country_id',  # noqa TODO push varname back into static data somehow?
                        static.provinces().file + '::GID->province_id',
                        static.basins().file + '::HYBAS_ID->basin_id'
                    ],
                    output=workspace.power_plants()
                )
            ]
        )
    ]


def append_boundaries(*, points: str, boundaries: Union[str, List[str]], output: str) -> List[str]:
    if type(boundaries) is str:
        boundaries = [boundaries]

    cmd = [
        os.path.join('{BINDIR}', 'utils', 'global_power_plant_database', 'append_boundaries.R'),
        '--points', points,
        '--output', output
    ]

    for b in boundaries:
        cmd += ['--boundaries', '"{}"'.format(b)]

    return cmd


def wsim_basin_losses(*,
                      basin_windows: str,
                      basin_stress: str,
                      bt_ro: Iterable[Vardef],
                      bt_ro_min_fits: List[str],
                      bt_ro_fits: List[str],
                      output: str) -> List[str]:
    cmd = [
        os.path.join('{BINDIR}', 'wsim_electricity_basin_loss_factors.R'),
        '--windows', '"{}"'.format(basin_windows),
        '--stress', '"{}"'.format(basin_stress),
        '--output', output
    ]

    for vardef in bt_ro:
        cmd += ['--bt_ro', "{}".format(vardef)]

    for filename in bt_ro_fits:
        cmd += ['--bt_ro_fit', filename]

    for filename in bt_ro_min_fits:
        cmd += ['--bt_ro_min_fit', filename]

    return cmd


def wsim_plant_losses(*,
                      plants: str,
                      basin_losses: str,
                      basin_temp: Union[str, Vardef],
                      temperature: Union[str, Vardef],
                      temperature_rp: Union[str, Vardef],
                      output: str) -> List[str]:
    return [
        os.path.join('{BINDIR}', 'wsim_electricity_plant_losses.R'),
        '--plants', plants,
        '--basin_losses',   '"{}"'.format(basin_losses),
        '--basin_temp',     '"{}"'.format(basin_temp),
        '--temperature',    '"{}"'.format(temperature),
        '--temperature_rp', '"{}"'.format(temperature_rp),
        '--output',         '"{}"'.format(output)
    ]


def compute_plant_losses(workspace: DefaultWorkspace,
                         *,
                         yearmon: str,
                         target: Optional[str]=None,
                         member: Optional[str]=None) -> List[Step]:
    return [
        Step(
            targets=workspace.electric_loss_risk(yearmon=yearmon, target=target, member=member, basis='plant'),
            dependencies=[
                workspace.power_plants(),
                workspace.basin_loss_factors(yearmon=yearmon, target=target, member=member),
                workspace.results(yearmon=yearmon, window=1, basis='basin', target=target, member=member),
                workspace.forcing(yearmon=yearmon, target=target, member=member),
                workspace.return_period(yearmon=yearmon, target=target, member=member, window=1)
            ],
            commands=[
                wsim_plant_losses(plants=workspace.power_plants(),
                                  basin_losses=read_vars(workspace.basin_loss_factors(yearmon=yearmon,
                                                                                      target=target,
                                                                                      member=member),
                                                         'water_cooled_loss',
                                                         'hydropower_loss'),
                                  basin_temp=Vardef(
                                      workspace.results(yearmon=yearmon,
                                                        window=1,
                                                        basis='basin',
                                                        target=target,
                                                        member=member),
                                      'T_Bt_RO'),
                                  temperature=Vardef(
                                      workspace.forcing(yearmon=yearmon, target=target, member=member),
                                      'T'),
                                  temperature_rp=Vardef(
                                      workspace.return_period(yearmon=yearmon, window=1, target=target, member=member),
                                      'T_rp'
                                  ),
                                  output=workspace.electric_loss_risk(yearmon=yearmon,
                                                                      target=target,
                                                                      member=member,
                                                                      basis='plant'))
            ]
        )
    ]


def compute_basin_integration_windows(workspace: DefaultWorkspace, static: ElectricityStatic) -> List[Step]:
    annual_flow_fit =  workspace.fit_obs(var='Bt_RO', month=12, window=12, stat='sum', basis='basin')

    return [
        Step(
            targets=workspace.basin_upstream_storage(),
            dependencies=[static.basins(), static.dam_locations(), annual_flow_fit],
            commands=[
                [
                    os.path.join('{BINDIR}', 'utils', 'hydrobasins', 'compute_upstream_storage.R'),
                    '--flow', annual_flow_fit,
                    '--dams', static.dam_locations().file,
                    '--basins', static.basins().file,
                    '--output', workspace.basin_upstream_storage(),
                ]
            ]
        )
    ]


def compute_basin_loss_factors(workspace: DefaultWorkspace,
                               *,
                               yearmon: str,
                               target: Optional[str]=None,
                               member: Optional[str]=None) -> List[Step]:
    bt_ro = []
    bt_ro_fits = []
    bt_ro_min_fits = []

    windows = (1, 3, 6, 12, 24, 36)
    year, month = parse_yearmon(yearmon)

    for w in windows:
        bt_ro.append(Vardef(workspace.results(basis='basin', yearmon=yearmon, window=w, target=target, member=member),
                            'Bt_RO' if w == 1 else 'Bt_RO_sum'))

        # For integration periods < 12 months, use the distribution of annual minimum N-month sums.
        # For integration periods >= 12 months, just use the N-month sum ending in December.
        bt_ro_min_fits.append(workspace.fit_obs(basis='basin',
                                            var='Bt_RO',
                                            stat='sum' if w != 1 else None,
                                            window=w,
                                            annual_stat='min' if w < 12 else None,
                                            month=12 if w >= 12 else None))

        bt_ro_fits.append(workspace.fit_obs(basis='basin',
                                            var='Bt_RO',
                                            stat='sum' if w != 1 else None,
                                            window=w,
                                            month=month))

    outfile = workspace.basin_loss_factors(yearmon=yearmon, target=target, member=member)

    return [
        Step(
            targets=[outfile],
            dependencies=[v.file for v in bt_ro] + bt_ro_fits + bt_ro_min_fits +
                         [workspace.basin_water_stress(), workspace.basin_upstream_storage()],
            commands=[
                wsim_basin_losses(
                    basin_windows=workspace.basin_upstream_storage(),
                    basin_stress=workspace.basin_water_stress(),
                    bt_ro=bt_ro,
                    bt_ro_min_fits=bt_ro_min_fits,
                    bt_ro_fits=bt_ro_fits,
                    output=outfile
                )
            ]
        )
    ]


def compute_basin_water_stress(workspace: DefaultWorkspace, static: ElectricityStatic) -> List[Step]:
    # FIXME this is a bit ugly, because the tempfile names are determined
    # when the workflow is processed, not when it is executed. While this
    # could be improved, the issue will go away when exactextract is updated
    # to output netCDF directly.

    temp_csv = tempfile.mktemp(suffix='.csv')
    temp_nc = tempfile.mktemp(suffix='.nc')

    return [
        commands.exact_extract(
            boundaries=static.basins().file,
            fid='HYBAS_ID',
            input=static.water_stress().file,
            output=temp_csv,
            stats='mean'
        ).merge(
            commands.table2nc(
                input=temp_csv,
                fid="HYBAS_ID",
                column="mean",
                output=temp_nc
            )
        ).merge(
            commands.wsim_merge(
                inputs=Vardef(temp_nc, 'mean').read_as('baseline_water_stress'),
                output=workspace.basin_water_stress()
            )
        )
    ]


def wsim_aggregate_losses(*,
                          plants: str,
                          plant_losses: Vardef,
                          basis: str,
                          output: str) -> List[str]:
    return [
        os.path.join('{BINDIR}', 'wsim_electricity_aggregate_losses.R'),
        '--plants',        plants,
        '--plant_losses',  '"{}"'.format(plant_losses),
        '--basis',         basis,
        '--output',        '"{}"'.format(output)
    ]


def compute_aggregated_losses(workspace: DefaultWorkspace,
                              *,
                              yearmon: str,
                              target: Optional[str]=None,
                              member: Optional[str]=None,
                              basis: str
                              ) -> List[Step]:

    plants = workspace.power_plants()
    plant_losses = Vardef(workspace.electric_loss_risk(yearmon=yearmon,
                                                       target=target,
                                                       member=member,
                                                       basis='plant'), 'loss_risk')
    aggregated_losses = workspace.electric_loss_risk(yearmon=yearmon,
                                                     target=target,
                                                     member=member,
                                                     basis=basis)

    return [Step(
        targets=aggregated_losses,
        dependencies=[plants, plant_losses],
        commands=[
            wsim_aggregate_losses(plants=plants,
                                  plant_losses=plant_losses,
                                  basis=basis,
                                  output=aggregated_losses)
        ]
    )]
