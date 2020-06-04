# Copyright (c) 2019-2020 ISciences, LLC.
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
from .dates import add_months, format_range, get_lead_months, get_next_yearmon, parse_yearmon
from .paths import AgricultureStatic, DefaultWorkspace, read_vars, Basis, Method, Sector, Vardef
from .step import Step
from . import commands

AGGREGATION_POLYGONS = (Basis.COUNTRY, Basis.PROVINCE, Basis.BASIN)
CULTIVATION_METHODS = (Method.RAINFED, Method.IRRIGATED)


def spinup(config: ConfigBase, _meta_steps: Mapping[str, Step]) -> List[Step]:
    steps = []

    # TODO fit models

    return steps


def monthly_observed(config: ConfigBase, yearmon: str, meta_steps: Mapping[str, Step]) -> List[Step]:
    print('Generating agriculture steps for', yearmon, 'observed data')

    steps = []

    steps += meta_steps['agriculture_assessment'].require(
        compute_yield_anomalies(config.workspace(), config.static_data(), yearmon=yearmon)
    )

    ## Compute aggregated losses
    #for basis in AGGREGATION_POLYGONS:
    #    steps += meta_steps['agriculture_assessment'].require(
    #        compute_aggregated_losses(config.workspace(), config.static_data(), yearmon=yearmon, basis=basis)
    #    )

    return steps


def monthly_forecast(config: ConfigBase, yearmon: str, meta_steps: Mapping[str, Step]) -> List[Step]:
    steps = []

    # Compute a gridded loss risk for each forecast ensemble member
    for model in config.models():
        print('Generating agriculture steps for', model)
        for member in config.forecast_ensemble_members(model, yearmon):
            steps += compute_yield_anomalies(config.workspace(), config.static_data(),
                                             yearmon=yearmon, model=model, member=member)

        #for basis in AGGREGATION_POLYGONS:
        #    steps += meta_steps['agriculture_assessment'].require(
        #        compute_aggregated_losses(config.workspace(),
        #                                  config.static_data(),
        #                                  yearmon=yearmon,
        #                                  target=target,
        #                                  summary=True,
        #                                  basis=basis)
        #    )

    return steps


def compute_loss_summary(config: ConfigBase, *,
                         yearmon: str,
                         target: str,
                         method: Method) -> List[Step]:

    loss_vars = ('loss',
                 'cumulative_loss_current_year',
                 'cumulative_loss_next_year')

    ws = config.workspace()
    inputs = []
    weights = []

    for model, member, weight in config.weighted_members(yearmon):
        inputs.append(ws.results(sector=Sector.AGRICULTURE, method=method, model=model, yearmon=yearmon, window=1, target=target, member=member))
        weights.append(weight)

    return [
        commands.wsim_integrate(
            inputs=inputs,
            weights=weights,
            stats=['q{}::{}'.format(q, ','.join(loss_vars)) for q in (25, 50, 75)],
            output=ws.results(sector=Sector.AGRICULTURE,
                              yearmon=yearmon,
                              target=target,
                              method=method,
                              window=1,
                              summary=True)
        )
    ]


def compute_expected_losses(workspace: DefaultWorkspace):
    outputs = [workspace.loss_params(sector=Sector.AGRICULTURE, method=method) for method in CULTIVATION_METHODS]

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
                              basis: Basis,
                              summary: Optional[bool]=False
                              ) -> List[Step]:

    # FIXME get id_field from somewhere
    if basis == Basis.COUNTRY:
        boundaries = static.countries().file
        id_field = 'GID'
    elif basis == Basis.PROVINCE:
        boundaries = static.provinces().file
        id_field = 'GID'
    elif basis == Basis.BASIN:
        boundaries = static.basins().file
        id_field = 'HYBAS_ID'
    else:
        raise Exception("Not yet.")

    aggregated_results = workspace.results(
        sector=Sector.AGRICULTURE, basis=basis,
        yearmon=yearmon, window=1, member=member, target=target, summary=summary)

    loss = {method: workspace.results(sector=Sector.AGRICULTURE, method=method,
                                      yearmon=yearmon, window=1, member=member, target=target, summary=summary)
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
                    '--prod_i', prod[Method.IRRIGATED],
                    '--loss_i', loss[Method.IRRIGATED],
                    '--prod_r', prod[Method.RAINFED],
                    '--loss_r', loss[Method.RAINFED],
                    '--output', aggregated_results
                ]
            ]
        )
    ]


def make_initial_state(workspace: DefaultWorkspace, method: Method, yearmon: str) -> List[Step]:
    state = workspace.state(sector=Sector.AGRICULTURE, method=method, yearmon=yearmon)

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
    annual_flow_fit = workspace.fit_obs(var='Bt_RO', month=12, window=12, stat='sum', basis=Basis.BASIN)

    return [
        Step(
            targets=workspace.basin_upstream_storage(sector=Sector.AGRICULTURE),
            dependencies=[static.basins(), static.dam_locations(), annual_flow_fit],
            commands=[
                [
                    os.path.join('{BINDIR}', 'utils', 'hydrobasins', 'compute_upstream_storage.R'),
                    '--flow', annual_flow_fit,
                    '--dams', static.dam_locations().file,
                    '--basins', static.basins().file,
                    '--sector', 'agriculture',
                    '--output', workspace.basin_upstream_storage(sector=Sector.AGRICULTURE),
                ]
            ]
        )
    ]


def compute_gridded_b2b_btro(workspace: DefaultWorkspace,
                             static: AgricultureStatic, *,
                             yearmon: str,
                             model: Optional[str] = None,
                             target: Optional[str] = None,
                             member: Optional[str] = None) -> List[Step]:
    windows = (1, 3, 6, 12, 24, 36)

    bt_ro = []
    bt_ro_fits = []

    year, month = parse_yearmon(yearmon)

    for w in windows:
        bt_ro.append(Vardef(workspace.results(basis=Basis.BASIN, model=model, yearmon=yearmon, window=w, target=target, member=member),
                            'Bt_RO' if w == 1 else 'Bt_RO_sum'))

        bt_ro_fits.append(workspace.fit_obs(basis=Basis.BASIN,
                                            var='Bt_RO',
                                            stat='sum' if w != 1 else None,
                                            window=w,
                                            month=month))

    outfile = workspace.agriculture_bt_ro_rp(model=model, yearmon=yearmon, target=target, member=member)

    return [
        Step(
            targets=[outfile],
            dependencies=[v.file for v in bt_ro] +
                         bt_ro_fits +
                         [workspace.basin_upstream_storage(sector=Sector.AGRICULTURE)],
            commands=[
                wsim_ag_b2b_rasterize(
                    basins=static.basins().file,
                    bt_ro=bt_ro,
                    fits=bt_ro_fits,
                    windows=workspace.basin_upstream_storage(sector=Sector.AGRICULTURE),
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
                      method: Method,
                      yearmon: str,
                      model: Optional[str] = None,
                      target: Optional[str] = None,
                      member: Optional[str] = None) -> List[Step]:
    if member:
        if get_lead_months(yearmon, target) > 1:
            current_state = workspace.state(sector=Sector.AGRICULTURE, method=method, yearmon=yearmon, target=target,
                                            model=model, member=member)
        else:
            current_state = workspace.state(sector=Sector.AGRICULTURE, method=method, yearmon=target)

        next_state = workspace.state(sector=Sector.AGRICULTURE, method=method, yearmon=yearmon,
                                     target=get_next_yearmon(target), model=model, member=member)
    else:
        current_state = workspace.state(sector=Sector.AGRICULTURE, method=method, yearmon=yearmon)
        next_state = workspace.state(sector=Sector.AGRICULTURE, method=method, yearmon=get_next_yearmon(yearmon))

    results = workspace.results(sector=Sector.AGRICULTURE, method=method, yearmon=yearmon, window=1, target=target,
                                model=model, member=member)

    temperature_rp = read_vars(workspace.return_period(yearmon=yearmon, window=1, model=model, member=member, target=target), 'T_rp')

    calendar = static.crop_calendar(method)
    loss_params = workspace.loss_params(sector=Sector.AGRICULTURE, method=method)

    surplus = read_vars(workspace.return_period(yearmon=yearmon, window=1, model=model, member=member, target=target), 'RO_mm_rp')
    if method == Method.IRRIGATED:
        deficit = workspace.agriculture_bt_ro_rp(yearmon=yearmon, model=model, member=member, target=target)
    elif method == Method.RAINFED:
        deficit = read_vars(workspace.return_period(yearmon=yearmon, model=model, window=1, member=member, target=target),
                            'PETmE_rp@negate',
                            'Ws_rp')
    else:
        raise Exception('Unknown cultivation method:', method.value)

    return [
        Step(
            targets=[results, next_state],
            dependencies=[current_state, surplus, deficit, temperature_rp, calendar, loss_params],
            commands=[
                wsim_ag(state=current_state,
                        next_state=next_state,
                        results=results,
                        surplus=surplus,
                        deficit=deficit,
                        temperature_rp=temperature_rp,
                        calendar=static.crop_calendar(method=method),
                        loss_params=loss_params,
                        yearmon=target if target else yearmon)
            ]
        )
    ]


def compute_yield_anomalies(workspace: DefaultWorkspace,
                            static: AgricultureStatic,
                            *,
                            yearmon: str,
                            latest_target: Optional[str] = None,
                            model: Optional[str] = None,
                            member: Optional[str] = None) -> List[Step]:

    # We need up to 23 months of observed data and 9 months of forecast data.
    # Imagine that we run the model in December 2019.
    # One pixel has a crop with a growing season of February - January.
    # In this case we need observed data from February 2018 - January 2019 to calculate the yield anomaly.
    # Another pixel has a growing season of January - December.
    # In this case we need observed data from January 2019 - December 2019 to calculate the yield anomaly.
    earliest_obs = add_months(yearmon, -22)
    obs_range = format_range(earliest_obs, yearmon, 1)

    anoms = [workspace.standard_anomaly(yearmon=obs_range, window=1)]

    if latest_target:
        earliest_target = add_months(yearmon, 1)
        fcst_range = format_range(earliest_target, latest_target)

        fcst_anoms = workspace.standard_anomaly(yearmon=yearmon,
                                                window=1,
                                                target=fcst_range,
                                                model=model,
                                                member=member)
        anoms.append(fcst_anoms)

    models = (
        'maize',
        'potatoes',
        'rice',
        'soybeans',
        'spring_wheat',
        'winter_wheat',
    )

    results = workspace.results(sector=Sector.AGRICULTURE,
                                yearmon=yearmon,
                                window=1,
                                member=member,
                                model=model,
                                target=None)

    return [
        Step(
            targets=results,
            dependencies=anoms + [
                static.crop_calendar(Method.IRRIGATED),
                static.crop_calendar(Method.RAINFED),
                static.production(Method.IRRIGATED),
                static.production(Method.RAINFED)
            ] + [static.ag_yield_anomaly_model(m) for m in models],
            commands=[
                wsim_ag2(yearmon=yearmon,
                         anom=anoms,
                         calendar_irrigated=static.crop_calendar(Method.IRRIGATED),
                         calendar_rainfed=static.crop_calendar(Method.RAINFED),
                         production_irrigated=static.production(Method.IRRIGATED).file,
                         production_rainfed=static.production(Method.RAINFED).file,
                         model_spring_wheat=static.ag_yield_anomaly_model('spring_wheat'),
                         model_winter_wheat=static.ag_yield_anomaly_model('winter_wheat'),
                         model_potatoes=static.ag_yield_anomaly_model('potatoes'),
                         model_maize = static.ag_yield_anomaly_model('maize'),
                         model_rice=static.ag_yield_anomaly_model('rice'),
                         model_soybeans=static.ag_yield_anomaly_model('soybeans'),
                         output=results)
            ]
        )
    ]


def wsim_ag2(*,
             yearmon: str,
             anom: Union[str, List[str]],
             calendar_irrigated: str,
             calendar_rainfed: str,
             production_irrigated: str,
             production_rainfed: str,
             model_spring_wheat: str,
             model_winter_wheat: str,
             model_maize: str,
             model_soybeans: str,
             model_potatoes: str,
             model_rice: str,
             output: str) -> List[str]:

    if type(anom) is str:
        anom = [anom]

    command = [
        os.path.join('{BINDIR}', 'wsim_ag2.R'),
        '--yearmon', yearmon,
        '--calendar_irr', calendar_irrigated,
        '--calendar_rf', calendar_rainfed,
        '--prod_irr', production_irrigated,
        '--prod_rf', production_rainfed,
        '--model_spring_wheat', model_spring_wheat,
        '--model_winter_wheat', model_winter_wheat,
        '--model_maize', model_maize,
        '--model_soybeans', model_soybeans,
        '--model_potatoes', model_potatoes,
        '--model_rice', model_rice
    ]

    for a in anom:
        command += ['--anom', '"{}"'.format(a)]

    command += ['--output', output]

    return command



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
        '--loss_method', 'max',
        '--output_dir', output_dir
    ]
