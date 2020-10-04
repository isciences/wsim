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
from .dates import add_months, format_range
from .paths import AgricultureStatic, DefaultWorkspace, Basis, Method, Sector
from .step import Step
from . import commands

AGGREGATION_POLYGONS = (Basis.COUNTRY, Basis.PROVINCE, Basis.BASIN)
CULTIVATION_METHODS = (Method.RAINFED, Method.IRRIGATED)

AG_MODELS = (
    'maize',
    'potatoes',
    'rice',
    'soybeans',
    'spring_wheat',
    'winter_wheat',
)


def spinup(_config: ConfigBase, _meta_steps: Mapping[str, Step]) -> List[Step]:
    steps = []

    for model in AG_MODELS:
        url = 'https://wsim-datasets.s3.us-east-2.amazonaws.com/ag_models/r7_{}.rds'.format(model)
        dir = os.path.dirname(_config.static_data().ag_yield_anomaly_model(model))
        steps.append(commands.download(url, dir))

    return steps


def monthly_observed(config: ConfigBase, yearmon: str, meta_steps: Mapping[str, Step]) -> List[Step]:
    print('Generating agriculture steps for', yearmon, 'observed data')

    steps = []

    # The random forest model requires that we provide conditions from the present until the next year's harvest,
    # potentially 23 months in the future depending on the crop/pixel. The process is set up to use climate
    # norms when forecasts are not available, so the usefulness of a result based only on observed data is not clear.
    # If we want one, we can explictly generate one by running a configuration using climate norms as forecasts.
    # Therefore, this is disabled by default, since the aggregated yield anomalies are relatively expensive to
    # compute.

    #steps += meta_steps['agriculture_assessment'].require(
    #    compute_yield_anomalies(config.workspace(), config.static_data(), yearmon=yearmon)
    #)

    #for basis in AGGREGATION_POLYGONS:
    #    steps += meta_steps['agriculture_assessment'].require(
    #        compute_aggregated_losses(config.workspace(), config.static_data(), yearmon=yearmon, summary=False, basis=basis)
    #    )

    return steps


def monthly_forecast(config: ConfigBase, yearmon: str, meta_steps: Mapping[str, Step]) -> List[Step]:
    steps = []

    # Compute gridded yield fractions for each forecast ensemble member
    latest_target = config.forecast_targets(yearmon)[-1]

    for model in config.models():
        print('Generating agriculture steps for', model)
        for member in config.forecast_ensemble_members(model, yearmon):
            steps += compute_yield_anomalies(config.workspace(), config.static_data(),
                                             yearmon=yearmon, model=model, member=member, latest_target=latest_target)

        steps += meta_steps['agriculture_assessment'].require(
            compute_loss_summary(config, yearmon=yearmon)
        )

        for basis in AGGREGATION_POLYGONS:
            steps += meta_steps['agriculture_assessment'].require(
                compute_aggregated_losses(config.workspace(),
                                          config.static_data(),
                                          yearmon=yearmon,
                                          summary=True,
                                          basis=basis)
            )

    return steps


def compute_loss_summary(config: ConfigBase, *,
                         yearmon: str) -> List[Step]:

    ws = config.workspace()
    inputs = []
    weights = []

    for model, member, weight in config.weighted_members(yearmon):
        inputs.append(ws.results(sector=Sector.AGRICULTURE, model=model, yearmon=yearmon, window=1, member=member))
        weights.append(weight)

    return [
        commands.wsim_integrate(
            inputs=inputs,
            weights=weights,
            stats=['q25', 'q50', 'q75'],
            output=ws.results(sector=Sector.AGRICULTURE,
                              yearmon=yearmon,
                              window=1,
                              summary=True)
        )
    ]


def compute_aggregated_losses(workspace: DefaultWorkspace,
                              static: AgricultureStatic,
                              *,
                              yearmon: str,
                              basis: Basis,
                              summary: bool,
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
        yearmon=yearmon, window=1, summary=summary)

    yield_anom = workspace.results(sector=Sector.AGRICULTURE, yearmon=yearmon, window=1, summary=summary)
    prod = {method: static.production(method).file for method in CULTIVATION_METHODS}

    return [
        Step(
            targets=aggregated_results,
            dependencies=list(prod.values()) + [boundaries, yield_anom],
            commands=[
                [
                    '{BINDIR}/wsim_ag_aggregate.R',
                    '--boundaries', boundaries,
                    '--id_field', id_field,
                    '--prod_i', prod[Method.IRRIGATED],
                    '--prod_r', prod[Method.RAINFED],
                    '--yield_anom', yield_anom,
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
            ] + [static.ag_yield_anomaly_model(m) for m in AG_MODELS],
            commands=[
                wsim_ag(yearmon=yearmon,
                        anom=anoms,
                        calendar_irrigated=static.crop_calendar(Method.IRRIGATED),
                        calendar_rainfed=static.crop_calendar(Method.RAINFED),
                        production_irrigated=static.production(Method.IRRIGATED).file,
                        production_rainfed=static.production(Method.RAINFED).file,
                        model_spring_wheat=static.ag_yield_anomaly_model('spring_wheat'),
                        model_winter_wheat=static.ag_yield_anomaly_model('winter_wheat'),
                        model_potatoes=static.ag_yield_anomaly_model('potatoes'),
                        model_maize=static.ag_yield_anomaly_model('maize'),
                        model_rice=static.ag_yield_anomaly_model('rice'),
                        model_soybeans=static.ag_yield_anomaly_model('soybeans'),
                        seed=(hash(yearmon + member) >> 32) if member else None, # R only has 32 bit integers
                        output=results)
            ]
        )
    ]


def wsim_ag(*,
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
            seed: Optional[int] = None,
            output: str) -> List[str]:

    if type(anom) is str:
        anom = [anom]

    command = [
        os.path.join('{BINDIR}', 'wsim_ag.R'),
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

    if seed:
        command += ['--seed', '"{}"'.format(seed)] # quote in case of negative seed value

    command += ['--output', output]

    return command
