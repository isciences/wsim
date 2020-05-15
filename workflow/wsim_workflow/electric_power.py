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

from typing import Iterable, List, Mapping, Union, Optional

from . import actions, commands

from .dates import all_months
from .spinup import time_integrate_results
from .step import Step
from .paths import Basis, DefaultWorkspace, ElectricityStatic, Sector, Vardef
from .config_base import ConfigBase

AGGREGATION_POLYGONS = (Basis.BASIN, Basis.COUNTRY, Basis.PROVINCE)


def spinup(config: ConfigBase, meta_steps: Mapping[str, Step]) -> List[Step]:
    steps = []
    all_fits = meta_steps['all_fits']
    windows = [w for w in config.integration_windows() if w >= 12]

    b2b_steps = []
    for yearmon in config.historical_yearmons():
        b2b_steps += actions.compute_basin_results(workspace=config.workspace(),
                                                   static=config.static_data(),
                                                   yearmon=yearmon)

    steps += b2b_steps

    steps.append(Step(
        targets=config.workspace().tag('basin_spinup_1mo_results'),
        dependencies=[config.workspace().results(yearmon=yearmon, window=1, basis=Basis.BASIN)
                      for yearmon in config.historical_yearmons()]
    ))

    # Time-integrate the variables
    for window in windows:
        steps += time_integrate_results(config, window, basis=Basis.BASIN)

    # Compute time-integrated fits
    for window in windows:
        for param in config.lsm_integrated_var_names(basis=Basis.BASIN):
            for month in all_months:
                steps += all_fits.require(
                    actions.fit_var(config, param=param, window=window, month=month, basis=Basis.BASIN))

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
    windows = [w for w in config.integration_windows() if w >= 12]

    # Skip if we would already have run this date as part of spinup
    if yearmon not in config.historical_yearmons():
        if config.should_run_lsm(yearmon):
            steps += actions.compute_basin_results(workspace=config.workspace(),
                                                   static=config.static_data(),
                                                   yearmon=yearmon)

        # Do time integration
        for window in windows:
            steps += actions.time_integrate(config.workspace(),
                                            config.lsm_integrated_stats(basis=Basis.BASIN),
                                            yearmon=yearmon,
                                            window=window,
                                            forcing=False,
                                            basis=Basis.BASIN)

    if yearmon not in config.result_fit_yearmons():
        for window in windows:
            steps += actions.compute_return_periods(config.workspace(),
                                                    result_vars=config.lsm_integrated_var_names(basis=Basis.BASIN),
                                                    yearmon=yearmon,
                                                    window=window,
                                                    basis=Basis.BASIN)

        # Compute basin loss factors
        steps += compute_basin_loss_factors(config.workspace(), yearmon=yearmon)

        # Compute aggregated losses
        for basis in AGGREGATION_POLYGONS:
            steps += meta_steps['electric_power_assessment'].require(
                compute_aggregated_losses(config.workspace(), yearmon=yearmon, basis=basis)
            )

    return steps


def monthly_forecast(config: ConfigBase, yearmon: str, meta_steps: Mapping[str, Step]) -> List[Step]:
    steps = []
    windows = [w for w in config.integration_windows() if w >= 12]

    for target in config.forecast_targets(yearmon):
        for model in config.models():
            print('Generating electric power steps for', model, yearmon, 'forecast target', target)
            for member in config.forecast_ensemble_members(model, yearmon):
                steps += actions.compute_basin_results(workspace=config.workspace(),
                                                       static=config.static_data(),
                                                       yearmon=yearmon,
                                                       target=target,
                                                       model=model,
                                                       member=member)

                for window in windows:
                    steps += actions.time_integrate(config.workspace(),
                                                    config.lsm_integrated_stats(basis=Basis.BASIN),
                                                    yearmon=yearmon,
                                                    target=target,
                                                    model=model,
                                                    member=member,
                                                    window=window,
                                                    basis=Basis.BASIN,
                                                    forcing=False)

                steps += compute_basin_loss_factors(config.workspace(), yearmon=yearmon, target=target, model=model, member=member)

                for basis in AGGREGATION_POLYGONS:
                    steps += compute_aggregated_losses(config.workspace(), yearmon=yearmon, basis=basis, target=target, model=model, member=member)

        for basis in AGGREGATION_POLYGONS:
            steps += meta_steps['electric_power_assessment'].require(
                compute_loss_summary(config, yearmon=yearmon, target=target, basis=basis))

    return steps


def compute_loss_summary(config: ConfigBase, *,
                         yearmon: str,
                         target: str,
                         basis: Basis) -> List[Step]:

    loss_vars = ('gross_loss_mw',  'hydro_loss_mw',
                 'gross_loss_pct', 'hydro_loss_pct',
                 )

    ws = config.workspace()

    inputs = []
    weights = []

    for model, member, weight in config.weighted_members(yearmon):
        inputs.append(ws.results(basis=basis,
                                 sector=Sector.ELECTRIC_POWER,
                                 model=model,
                                 yearmon=yearmon,
                                 window=12,
                                 target=target,
                                 member=member))
        weights.append(weight)

    return [
        commands.wsim_integrate(
            inputs=inputs,
            weights=weights,
            stats=['q{}::{}'.format(q, ','.join(loss_vars)) for q in (25, 50, 75)],
            output=ws.results(sector=Sector.ELECTRIC_POWER,
                              yearmon=yearmon,
                              target=target,
                              basis=basis,
                              window=12,
                              summary=True)
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
                      bt_ro: Iterable[Vardef],
                      bt_ro_fits: List[str],
                      output: str) -> List[str]:
    cmd = [
        os.path.join('{BINDIR}', 'wsim_electricity_basin_loss_factors.R'),
        '--windows', '"{}"'.format(basin_windows),
        '--output', output
    ]

    for vardef in bt_ro:
        cmd += ['--bt_ro', "{}".format(vardef)]

    for filename in bt_ro_fits:
        cmd += ['--bt_ro_fit', filename]

    return cmd


def compute_basin_integration_windows(workspace: DefaultWorkspace, static: ElectricityStatic) -> List[Step]:
    annual_flow_fit = workspace.fit_obs(var='Bt_RO', month=12, window=12, stat='sum', basis=Basis.BASIN)

    return [
        Step(
            targets=workspace.basin_upstream_storage(sector=Sector.ELECTRIC_POWER),
            dependencies=[static.basins(), static.dam_locations(), annual_flow_fit],
            commands=[
                [
                    os.path.join('{BINDIR}', 'utils', 'hydrobasins', 'compute_upstream_storage.R'),
                    '--flow', annual_flow_fit,
                    '--dams', static.dam_locations().file,
                    '--basins', static.basins().file,
                    '--sector', 'electric_power',
                    '--output', workspace.basin_upstream_storage(sector=Sector.ELECTRIC_POWER),
                ]
            ]
        )
    ]


def compute_basin_loss_factors(workspace: DefaultWorkspace,
                               *,
                               yearmon: str,
                               target: Optional[str] = None,
                               model: Optional[str] = None,
                               member: Optional[str] = None) -> List[Step]:
    bt_ro = []
    bt_ro_fits = []

    windows = (12, 24, 36)

    for w in windows:
        bt_ro.append(Vardef(workspace.results(basis=Basis.BASIN,
                                              model=model,
                                              yearmon=yearmon,
                                              window=w,
                                              target=target,
                                              member=member),
                            'Bt_RO_sum'))

        # Since our integration windows are all multiples of 12 months, always compare flow values
        # against the N-month sum ending in December. (The distribution of June-May flow sums should
        # be the same as the distribution of Jan-December flow sums.)
        assert all((w/12).is_integer() for w in windows)
        bt_ro_fits.append(workspace.fit_obs(basis=Basis.BASIN,
                                            var='Bt_RO',
                                            stat='sum',
                                            window=w,
                                            month=12))

    outfile = workspace.basin_loss_factors(yearmon=yearmon, model=model, target=target, member=member)

    return [
        Step(
            targets=[outfile],
            dependencies=[v.file for v in bt_ro] + bt_ro_fits +
                         [workspace.basin_upstream_storage(sector=Sector.ELECTRIC_POWER)],
            commands=[
                wsim_basin_losses(
                    basin_windows=workspace.basin_upstream_storage(sector=Sector.ELECTRIC_POWER),
                    bt_ro=bt_ro,
                    bt_ro_fits=bt_ro_fits,
                    output=outfile
                )
            ]
        )
    ]


def compute_basin_water_stress(workspace: DefaultWorkspace, static: ElectricityStatic) -> List[Step]:
    return [
        commands.exact_extract(
            boundaries=static.basins().file,
            fid='HYBAS_ID',
            id_name='id',
            id_type='int32',
            rasters={'water_stress': static.water_stress().file},
            output=workspace.basin_water_stress(),
            stats='baseline_water_stress=mean(water_stress)'
        )
    ]


def wsim_aggregate_losses(*,
                          plants: str,
                          basin_losses: Vardef,
                          basis: Basis,
                          yearmon: str,
                          output: str) -> List[str]:
    return [
        os.path.join('{BINDIR}', 'wsim_electricity_aggregate_losses.R'),
        '--plants',        plants,
        '--basin_losses',  '"{}"'.format(basin_losses),
        '--basis',         basis.value,
        '--yearmon',       yearmon,
        '--output',        '"{}"'.format(output)
    ]


def compute_aggregated_losses(workspace: DefaultWorkspace,
                              *,
                              yearmon: str,
                              model: Optional[str] = None,
                              target: Optional[str] = None,
                              member: Optional[str] = None,
                              basis: Basis
                              ) -> List[Step]:

    plants = workspace.power_plants()
    basin_losses = Vardef(workspace.basin_loss_factors(yearmon=yearmon, model=model, target=target, member=member),
                          'hydropower_loss')
    aggregated_losses = workspace.results(sector=Sector.ELECTRIC_POWER,
                                          yearmon=yearmon,
                                          model=model,
                                          target=target,
                                          member=member,
                                          window=12,
                                          basis=basis)

    return [Step(
        targets=aggregated_losses,
        dependencies=[plants, basin_losses],
        commands=[
            wsim_aggregate_losses(plants=plants,
                                  basin_losses=basin_losses,
                                  basis=basis,
                                  output=aggregated_losses,
                                  yearmon=target if target else yearmon)
        ]
    )]
