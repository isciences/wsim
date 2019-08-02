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

import itertools

from typing import Dict, List, Optional, Union

from . import attributes as attrs

from .paths import read_vars, Basis, Vardef, DefaultWorkspace, ObservedForcing, ForecastForcing, ElectricityStatic, Static
from .commands import \
    exact_extract, \
    wsim_anom, \
    wsim_composite, \
    wsim_correct, \
    wsim_fit, \
    wsim_flow, \
    wsim_integrate, \
    wsim_lsm, \
    wsim_merge
from .config_base import ConfigBase

from .dates import get_next_yearmon, get_lead_months, rolling_window, available_yearmon_range
from .step import Step


def create_forcing_file(workspace: DefaultWorkspace,
                        data: Union[ObservedForcing, ForecastForcing],
                        *,
                        window: int,
                        yearmon: str,
                        target: Optional[str]=None,
                        member: Optional[str]=None) -> List[Step]:

    precip = data.precip_monthly(yearmon=yearmon, target=target, member=member)
    temp = data.temp_monthly(yearmon=yearmon, target=target, member=member)
    wetdays = data.p_wetdays(yearmon=yearmon, target=target, member=member)

    return [
        wsim_merge(
            inputs=[
                precip.read_as('Pr'),
                temp.read_as('T'),
                wetdays.read_as('pWetDays')
            ],
            attrs=list(filter(None, [
                ('target=' + target) if target else None,
                ('member=' + member) if member else None,
                'T:units',
                'T:standard_name',
                'Pr:units',
                'Pr:standard_name'
            ])),
            output=workspace.forcing(yearmon=yearmon, target=target, member=member, window=window)
        )
    ]


def compute_basin_results(workspace: DefaultWorkspace,
                          static: ElectricityStatic,
                          yearmon: str,
                          target: Optional[str]=None,
                          member: Optional[str]=None) -> List[Step]:
    pixel_forcing = workspace.forcing(yearmon=yearmon, target=target, member=member, window=1)
    pixel_results = workspace.results(yearmon=yearmon, window=1, target=target, member=member)
    basin_results = workspace.results(yearmon=yearmon, window=1, target=target, member=member, basis=Basis.BASIN)

    return [
        exact_extract(
            boundaries=static.basins().file,
            fid="HYBAS_ID",
            id_name="id",
            id_type="int32",
            rasters={
                'Bt_RO': 'NETCDF:{}:Bt_RO'.format(pixel_results),
                'RO_m3': 'NETCDF:{}:RO_m3'.format(pixel_results),
                'T': 'NETCDF:{}:T'.format(pixel_forcing)
            },
            stats=[
                'RO_m3=sum(RO_m3)',
                'T_Bt_RO=weighted_mean(RO_m3,Bt_RO)'
            ],
            output=basin_results
        ).merge(
            wsim_flow(
                input=read_vars(basin_results, 'RO_m3'),
                flowdir=static.basin_downstream(),
                varname='Bt_RO',
                output=basin_results
            )
        )
    ]


def run_lsm(workspace: DefaultWorkspace, static: Static, *,
            yearmon: str,
            target: Optional[str]=None,
            member: Optional[str]=None,
            lead_months: int=0) -> List[Step]:

    if member:
        if lead_months > 1:
            current_state = workspace.state(yearmon=yearmon, target=target, member=member)
        else:
            current_state = workspace.state(yearmon=target)

        next_state = workspace.state(yearmon=yearmon, target=get_next_yearmon(target), member=member)
    else:
        current_state = workspace.state(yearmon=yearmon)
        next_state = workspace.state(yearmon=get_next_yearmon(yearmon))

    results = workspace.results(yearmon=yearmon, window=1, target=target, member=member)
    forcing = workspace.forcing(yearmon=yearmon, target=target, member=member, window=1)

    return [
        wsim_lsm(
            state=current_state,
            elevation=static.elevation(),
            wc=static.wc(),
            flowdir=static.flowdir(),
            forcing=forcing,
            results=results,
            next_state=next_state
        )
    ]


def time_integrate(workspace: DefaultWorkspace,
                   integrated_stats: Dict[str, List[str]],
                   *,
                   yearmon: str,
                   target: Optional[str]=None,
                   window: Optional[int]=None,
                   member: Optional[str]=None,
                   basis: Optional[Basis]=None):
    months = rolling_window(target if target else yearmon, window)

    lead_months = get_lead_months(yearmon, target) if target else 0

    if lead_months > 0:
        window_observed = months[:-lead_months]
        window_forecast = months[-lead_months:]
    else:
        window_observed = months
        window_forecast = []

    prev_results = [workspace.results(yearmon=x, window=1, basis=basis) for x in window_observed] + \
                   [workspace.forcing(yearmon=x, window=1) for x in window_observed] + \
                   [workspace.results(yearmon=yearmon, member=member, target=x, window=1, basis=basis)
                    for x in window_forecast] + \
                   [workspace.forcing(yearmon=yearmon, member=member, target=x, window=1) for x in window_forecast]

    return [
        wsim_integrate(
            inputs=[read_vars(f, *set(itertools.chain(*integrated_stats.values()))) for f in prev_results],
            stats=[stat + '::' + ','.join(varname) for stat, varname in integrated_stats.items()],
            attrs=[attrs.integration_window(var='*', months=window)],
            output=workspace.results(yearmon=yearmon,
                                     window=window,
                                     target=target,
                                     member=member,
                                     temporary=False,
                                     basis=basis)
        )
    ]


def compute_return_periods(workspace: DefaultWorkspace, *,
                           forcing_vars: Optional[List[str]]=None,
                           result_vars: Optional[List[str]]=None,
                           state_vars: Optional[List[str]]=None,
                           yearmon: str,
                           window: int,
                           target: Optional[str]=None,
                           member: Optional[str]=None,
                           basis: Optional[Basis]=None) -> List[Step]:
    if target:
        month = int(target[-2:])
    else:
        month = int(yearmon[-2:])

    if forcing_vars is None:
        forcing_vars = []
    if result_vars is None:
        result_vars = []

    args = {'yearmon': yearmon, 'target': target, 'window': window, 'member': member, 'basis': basis}

    if basis:
        assert not forcing_vars

    if state_vars:
        assert window==1

    return [
        wsim_anom(
            fits=[workspace.fit_obs(var=var,
                                    window=window,
                                    month=month,
                                    basis=basis) for var in forcing_vars + result_vars],
            obs=[
                read_vars(workspace.results(**args), *result_vars)
                if result_vars else None,
                read_vars(workspace.forcing(yearmon=yearmon, target=target, window=window, member=member), *forcing_vars)
                if forcing_vars else None,
                read_vars(workspace.state(yearmon=yearmon), *state_vars) if state_vars else None
            ],
            rp=workspace.return_period(**args),
            sa=workspace.standard_anomaly(**args)
        )
    ]


def composite_vars(*, method: str, window: int, quantile: Optional[int]) -> Dict[str, Union[str, List[str]]]:
    quantile_text = '_q{}'.format(quantile) if quantile else ''

    if method == 'return_period':
        rp_or_sa = 'rp'
    elif method == 'standard_anomaly':
        rp_or_sa = 'sa'

    if window == 1:
        deficit = [
            'PETmE_{rp_or_sa}{quantile}@fill0@negate->Neg_PETmE',
            'Ws_{rp_or_sa}{quantile}->Ws',
            'Bt_RO_{rp_or_sa}{quantile}->Bt_RO'
        ]
        surplus = [
            'RO_mm_{rp_or_sa}{quantile}->RO_mm',
            'Bt_RO_{rp_or_sa}{quantile}->Bt_RO'
        ]
        mask = 'Ws_{rp_or_sa}{quantile}'
    else:
        deficit = [
            'PETmE_sum_{rp_or_sa}{quantile}@fill0@negate->Neg_PETmE',
            'Ws_ave_{rp_or_sa}{quantile}->Ws',
            'Bt_RO_sum_{rp_or_sa}{quantile}->Bt_RO'
        ]
        surplus = [
            'RO_mm_sum_{rp_or_sa}{quantile}->RO_mm',
            'Bt_RO_sum_{rp_or_sa}{quantile}->Bt_RO'
        ]
        mask = 'Ws_ave_{rp_or_sa}{quantile}'

    def fmt(x):
        return x.format(quantile=quantile_text, rp_or_sa=rp_or_sa)

    return {
        'deficit': [fmt(d) for d in deficit],
        'surplus': [fmt(s) for s in surplus],
        'mask': fmt(mask)
    }


def composite_indicators(workspace: DefaultWorkspace,
                         *,
                         yearmon: str,
                         window: Optional[int]=None,
                         target: Optional[str]=None,
                         quantile: Optional[int]=None) -> List[Step]:
    # If we're working with a forecast, we should have also have the desired
    # quantile of the ensemble members
    assert (quantile is None) == (target is None)

    cvars = composite_vars(method='return_period', window=window, quantile=quantile)

    if target:
        infile = workspace.return_period_summary(yearmon=yearmon, target=target, window=window)
    else:
        infile = workspace.return_period(yearmon=yearmon, window=window)

    return [
        wsim_composite(
            surplus=[infile + '::' + var for var in cvars['surplus']],
            deficit=[infile + '::' + var for var in cvars['deficit']],
            both_threshold=3,
            mask=infile + '::' + cvars['mask'],
            output=workspace.composite_summary(yearmon=yearmon, target=target, window=window),
            clamp=60
        )
    ]


def composite_indicator_return_periods(workspace: DefaultWorkspace,
                                       *,
                                       yearmon: str,
                                       window: int,
                                       target: Optional[str]=None) -> List[Step]:
    return [
        wsim_anom(
            fits=[
                workspace.fit_composite_anomalies(window=window, indicator='surplus'),
                workspace.fit_composite_anomalies(window=window, indicator='deficit')
            ],
            obs=read_vars(workspace.composite_anomaly(yearmon=yearmon, window=window, target=target),
                          'surplus', 'deficit'),
            rp=workspace.composite_anomaly_return_period(yearmon=yearmon, window=window, target=target, temporary=False)
        )
    ]


def composite_indicator_adjusted(workspace: DefaultWorkspace,
                                 *,
                                 yearmon: str,
                                 window: int,
                                 target: Optional[str]=None) -> List[Step]:
    return [
        wsim_composite(
            surplus=[Vardef(workspace.composite_anomaly_return_period(yearmon=yearmon, window=window, target=target),
                            'surplus_rp').read_as('surplus')],
            deficit=[Vardef(workspace.composite_anomaly_return_period(yearmon=yearmon, window=window, target=target),
                            'deficit_rp').read_as('deficit')],
            both_threshold=3,
            output=workspace.composite_summary_adjusted(yearmon=yearmon, window=window, target=target),
            clamp=60
        )
    ]


def composite_anomalies(workspace: DefaultWorkspace,
                        *,
                        yearmon: str,
                        window: Optional[int]=None,
                        target: Optional[str]=None,
                        quantile: Optional[int]=None) -> List[Step]:
    cvars = composite_vars(method='standard_anomaly', window=window, quantile=quantile)

    if target:
        infile = workspace.standard_anomaly_summary(yearmon=yearmon, target=target, window=window)
    else:
        infile = workspace.standard_anomaly(yearmon=yearmon, window=window)

    outfile = workspace.composite_anomaly(yearmon=yearmon, target=target, window=window)

    return [
        wsim_composite(
            surplus=[infile + '::' + var for var in cvars['surplus']],
            deficit=[infile + '::' + var for var in cvars['deficit']],
            both_threshold=0.4307273,  # corresponds with rp of 3
            mask=infile + '::' + cvars['mask'],
            output=outfile
        )
    ]


def fit_var(config: ConfigBase,
            *,
            param: str,
            month: int,
            stat: Optional[str]=None,
            window: int=1,
            basis: Optional[Basis]=None) -> List[Step]:
    """
    Compute fits for param in given month over fitting period
    """
    input_range = available_yearmon_range(window=window,
                                          month=month,
                                          start_year=config.result_fit_years()[0],
                                          end_year=config.result_fit_years()[-1])

    if stat:
        param_to_read = param + '_' + stat
    else:
        param_to_read = param

    if param in config.forcing_rp_vars():
        assert basis is None

        infile = config.workspace().forcing(yearmon=input_range, window=window)

    elif param in config.state_rp_vars():
        assert window == 1
        assert basis is None

        infile = config.workspace().state(yearmon=input_range)

    else:
        infile = config.workspace().results(yearmon=input_range, window=window, basis=basis)


    # Step for fits
    return [
        wsim_fit(
            distribution=config.distribution,
            inputs=read_vars(infile, param_to_read),
            output=config.workspace().fit_obs(var=param, stat=stat, month=month, window=window, basis=basis),
            window=window
        )
    ]


def forcing_summary(workspace: DefaultWorkspace, ensemble_members: List[str], *, yearmon: str, target: str) \
        -> List[Step]:
    return [
        wsim_integrate(
            inputs=[workspace.forcing(yearmon=yearmon, target=target, member=member, window=1) for member in ensemble_members],
            stats=['q25', 'q50', 'q75'],
            output=workspace.forcing_summary(yearmon=yearmon, target=target)
        )
    ]


def result_summary(workspace: DefaultWorkspace,
                   ensemble_members: List[str],
                   *,
                   yearmon: str,
                   target: str,
                   window: Optional[int]=None) -> List[Step]:
    return [
        wsim_integrate(
            inputs=[workspace.results(yearmon=yearmon, window=window, target=target, member=member)
                    for member in ensemble_members],
            stats=['q25', 'q50', 'q75'],
            output=workspace.results_summary(yearmon=yearmon, window=window, target=target)
        )
    ]


def return_period_summary(workspace: DefaultWorkspace,
                          ensemble_members: List[str],
                          *,
                          yearmon: str,
                          target: str,
                          window: Optional[int]=None) -> List[Step]:
    return [
        wsim_integrate(
            inputs=[workspace.return_period(yearmon=yearmon, target=target, window=window, member=member)
                    for member in ensemble_members],
            stats=['q25', 'q50', 'q75'],
            output=workspace.return_period_summary(yearmon=yearmon, window=window, target=target)
        )
    ]


def standard_anomaly_summary(workspace: DefaultWorkspace,
                             ensemble_members: List[str],
                             *,
                             yearmon: str,
                             target: str,
                             window: Optional[int]=None) -> List[Step]:
    return [
        wsim_integrate(
            inputs=[workspace.standard_anomaly(yearmon=yearmon, target=target, window=window, member=member)
                    for member in ensemble_members],
            stats=['q25', 'q50', 'q75'],
            output=workspace.standard_anomaly_summary(yearmon=yearmon, window=window, target=target)
        )
    ]


def correct_forecast(data: DefaultWorkspace, *, member: str, target: str, lead_months: int) -> List[Step]:
    target_month = int(target[-2:])

    return [
        wsim_correct(
            retro=[
                data.fit_retro(target_month=target_month, lead_months=lead_months, var='T'),
                data.fit_retro(target_month=target_month, lead_months=lead_months, var='Pr'),
            ],
            obs=[
                data.fit_obs(month=target_month, var='T'),
                data.fit_obs(month=target_month, var='Pr')
            ],
            forecast=data.forecast_raw(member=member, target=target) + '::tmp2m@[x-273.15]->T,prate@[x*2628000]->Pr',
            output=data.forecast_corrected(member=member, target=target),
            attrs=[
                "Pr:standard_name=precipitation_amount",
                "Pr:units=mm",
                "T:standard_name=surface_temperature",
                "T:units=degree_Celsius"
            ]
        )
    ]
