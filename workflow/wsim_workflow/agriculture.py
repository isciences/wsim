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

from typing import List, Mapping, Optional, Union

from .config_base import ConfigBase
from .dates import get_lead_months, get_next_yearmon, parse_yearmon
from .paths import AgricultureStatic, DefaultWorkspace, read_vars, Vardef
from .step import Step

AGGREGATION_POLYGONS = ('country', 'province', 'basin')
CULTIVATION_METHODS = ('rainfed', 'irrigated')


def spinup(config: ConfigBase, meta_steps: Mapping[str, Step]) -> List[Step]:
    steps = []

    dawn_of_agriculture = '200001'
    ag_assessment_yearmons = [yearmon for yearmon in config.historical_yearmons() if yearmon >= dawn_of_agriculture]

    for method in CULTIVATION_METHODS:
        steps += make_initial_state(config.workspace(), method, dawn_of_agriculture)

    steps += compute_basin_integration_windows(config.workspace(), config.static_data())

    steps += compute_expected_losses(config.workspace())

    for yearmon in ag_assessment_yearmons:
        steps += compute_gridded_b2b_btro(config.workspace(), config.static_data(), yearmon=yearmon)
        for method in CULTIVATION_METHODS:
            steps += compute_loss_risk(config.workspace(), config.static_data(), yearmon=yearmon, method=method)

    return steps


def monthly_observed(config: ConfigBase, yearmon: str, meta_steps: Mapping[str, Step]) -> List[Step]:
    print('Generating agriculture steps for', yearmon, 'observed data')

    steps = []

    if yearmon not in config.historical_yearmons():
        steps += compute_gridded_b2b_btro(config.workspace(), config.static_data(), yearmon=yearmon)
        for method in CULTIVATION_METHODS:
            steps += compute_loss_risk(config.workspace(), config.static_data(), yearmon=yearmon, method=method)

        # Compute aggregated losses
        for basis in AGGREGATION_POLYGONS:
            steps += meta_steps['agriculture_assessment'].require(
                compute_aggregated_losses(config.workspace(), config.static_data(), yearmon=yearmon, basis=basis)
            )

    return steps


def monthly_forecast(config: ConfigBase, yearmon: str, meta_steps: Mapping[str, Step]) -> List[Step]:
    steps = []

    # FIXME support forecasts

    return steps


def compute_expected_losses(workspace: DefaultWorkspace):
    outputs = [workspace.loss_params(sector='agriculture', method=method) for method in CULTIVATION_METHODS]

    return [
        Step(
            targets=outputs,
            commands=[
                wsim_ag_spinup(output_dir=os.path.dirname(outputs[0]))
            ]
        )
    ]


def compute_aggregated_losses(workspace: DefaultWorkspace,
                              static: AgricultureStatic,
                              *,
                              yearmon: str,
                              target: Optional[str]=None,
                              member: Optional[str]=None,
                              basis: str
                              ) -> List[Step]:

    # FIXME get id_field from somewhere
    if basis == 'country':
        boundaries = static.countries().file
        id_field = 'GID'
    elif basis == 'province':
        boundaries = static.provinces().file
        id_field = 'GID'
    elif basis == 'basin':
        boundaries = static.basins().file
        id_field = 'HYBAS_ID'
    else:
        raise Exception("Not yet.")

    # FIXME write .nc not .rds
    aggregated_results = workspace.results(
        sector='agriculture', basis=basis,
        yearmon=yearmon, window=1, member=member, target=target).replace('.nc', '.rds')

    loss = {method: workspace.results(sector='agriculture', method=method,
                                yearmon=yearmon, window=1, member=member, target=target)
              for method in CULTIVATION_METHODS}
    prod = {method: static.production(method).file for method in CULTIVATION_METHODS}

    return [
        Step(
            targets=aggregated_results,
            dependencies=list(loss.values()) + list(prod.values()) + [boundaries],
            commands=[
                [
                    '{BINDIR}/wsim_ag_aggregate.R',
                    '--boundaries', boundaries,
                    '--id_field', id_field,
                    '--prod_i', prod['irrigated'],
                    '--loss_i', loss['irrigated'],
                    '--prod_r', prod['rainfed'],
                    '--loss_r', loss['rainfed'],
                    '--output', aggregated_results
                ]
            ]
        )
    ]


def make_initial_state(workspace: DefaultWorkspace, method: str, yearmon: str) -> List[Step]:
    state = workspace.state(sector='agriculture', method=method, yearmon=yearmon)

    return [
        Step(targets=state,
             commands=[
                 [
                     'Rscript', '-e',
                     "'wsim.agriculture::write_empty_state(\"{}\")'".format(state)
                 ]
             ])
    ]


def compute_basin_integration_windows(workspace: DefaultWorkspace, static: AgricultureStatic) -> List[Step]:
    annual_flow_fit = workspace.fit_obs(var='Bt_RO', month=12, window=12, stat='sum', basis='basin')

    return [
        Step(
            targets=workspace.basin_upstream_storage(sector='agriculture'),
            dependencies=[static.basins(), static.dam_locations(), annual_flow_fit],
            commands=[
                [
                    os.path.join('{BINDIR}', 'utils', 'hydrobasins', 'compute_upstream_storage.R'),
                    '--flow', annual_flow_fit,
                    '--dams', static.dam_locations().file,
                    '--basins', static.basins().file,
                    '--sector', 'agriculture',
                    '--output', workspace.basin_upstream_storage(sector='agriculture'),
                ]
            ]
        )
    ]


def compute_gridded_b2b_btro(workspace: DefaultWorkspace,
                             static: AgricultureStatic, *,
                             yearmon: str,
                             target: Optional[str] = None,
                             member: Optional[str] = None) -> List[Step]:
    windows = (1, 3, 6, 12, 24, 36)

    bt_ro = []
    bt_ro_fits = []

    year, month = parse_yearmon(yearmon)

    for w in windows:
        bt_ro.append(Vardef(workspace.results(basis='basin', yearmon=yearmon, window=w, target=target, member=member),
                            'Bt_RO' if w == 1 else 'Bt_RO_sum'))

        bt_ro_fits.append(workspace.fit_obs(basis='basin',
                                            var='Bt_RO',
                                            stat='sum' if w != 1 else None,
                                            window=w,
                                            month=month))

    outfile = workspace.agriculture_bt_ro_rp(yearmon=yearmon, target=target, member=member)

    return [
        Step(
            targets=[outfile],
            dependencies=[v.file for v in bt_ro] +
                         bt_ro_fits +
                         [workspace.basin_upstream_storage(sector='agriculture')],
            commands=[
                wsim_ag_b2b_rasterize(
                    basins=static.basins().file,
                    bt_ro=bt_ro,
                    fits=bt_ro_fits,
                    windows=workspace.basin_upstream_storage(sector='agriculture'),
                    res=0.5,
                    output=outfile
                )
            ]
        )
    ]


def wsim_ag_b2b_rasterize(basins: List[str],
                          bt_ro: List[Vardef],
                          fits: List[str],
                          windows: str,
                          res: float,
                          output: str) -> List[str]:
    cmd = [
        '{BINDIR}/wsim_ag_b2b_rasterize.R',
        '--basins', basins,
        '--windows', windows,
        '--res', str(res),
        '--output', output
    ]

    for fit in fits:
        cmd += ['--fit', fit]

    for f in bt_ro:
        cmd += ['--bt_ro', str(f)]

    return cmd


def compute_loss_risk(workspace: DefaultWorkspace,
                      static: AgricultureStatic,
                      *,
                      method: str,
                      yearmon: str,
                      target: Optional[str] = None,
                      member: Optional[str] = None) -> List[Step]:
    if member:
        if get_lead_months(yearmon, target) > 1:
            current_state = workspace.state(sector='agriculture', method=method, yearmon=yearmon, target=target,
                                            member=member)
        else:
            current_state = workspace.state(sector='agriculture', method=method, yearmon=target)

        next_state = workspace.state(sector='agriculture', method=method, yearmon=yearmon,
                                     target=get_next_yearmon(target), member=member)
    else:
        current_state = workspace.state(sector='agriculture', method=method, yearmon=yearmon)
        next_state = workspace.state(sector='agriculture', method=method, yearmon=get_next_yearmon(yearmon))

    results = workspace.results(sector='agriculture', method=method, yearmon=yearmon, window=1, target=target,
                                member=member)

    temperature_rp = read_vars(workspace.return_period(yearmon=yearmon, window=1, member=member, target=target), 'T_rp')

    calendar = static.crop_calendar(method)
    loss_params = workspace.loss_params(sector='agriculture', method=method)

    surplus = read_vars(workspace.return_period(yearmon=yearmon, window=1, member=member, target=target), 'RO_mm_rp')
    if method == 'irrigated':
        deficit = workspace.agriculture_bt_ro_rp(yearmon=yearmon, member=member, target=target)
    elif method == 'rainfed':
        deficit = read_vars(workspace.return_period(yearmon=yearmon, window=1, member=member, target=target),
                            'PETmE_rp@negate',
                            'Ws_rp')
    else:
        raise Exception('Unknown cultivation method:', method)

    return [
        Step(
            targets=[results, next_state],
            dependencies=[current_state, surplus, deficit, temperature_rp, calendar, loss_params],
            commands=[
                wsim_ag(state=current_state,
                        next_state=next_state,
                        results=results,
                        extra_output=results.replace('results_1mo', 'extra'),
                        surplus=surplus,
                        deficit=deficit,
                        temperature_rp=temperature_rp,
                        calendar=static.crop_calendar(method=method),
                        loss_params=loss_params,
                        yearmon=target if target else yearmon)
            ]
        )
    ]


def wsim_ag(*,
            state: str,
            next_state: str,
            results: str,
            extra_output: Optional[str]=None,
            surplus: Union[str, List[str]],
            deficit: Union[str, List[str]],
            temperature_rp: str,
            calendar: str,
            yearmon: str,
            loss_params: str
            ) -> List[str]:
    if type(surplus) is str:
        surplus = [surplus]
    if type(deficit) is str:
        deficit = [deficit]

    cmd = [
        os.path.join('{BINDIR}', 'wsim_ag.R'),
        '--state', state,
        '--temperature_rp', temperature_rp,
        '--calendar', calendar,
        '--next_state', next_state,
        '--results', results,
        '--loss_params', loss_params,
        '--yearmon', yearmon
    ]

    for s in surplus:
        cmd += ['--surplus', s]

    for d in deficit:
        cmd += ['--deficit', d]

    if extra_output:
        cmd += ['--extra_output', extra_output]

    return cmd

def wsim_ag_spinup(*, output_dir: str):
    return [
        os.path.join('{BINDIR}', 'wsim_ag_spinup.R'),
        '--output_dir', output_dir
    ]
