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

import itertools

from .paths import read_vars, Vardef, date_range
from .commands import wsim_integrate, wsim_merge, wsim_anom, wsim_correct, wsim_composite, wsim_lsm, wsim_extract, wsim_flow, wsim_fit
from .dates import get_next_yearmon, rolling_window

def create_forcing_file(workspace, data, *, yearmon, target=None, member=None):

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
            attrs=filter(None, [
                ('target=' + target) if target else None,
                ('member=' + member) if member else None,
                'T:units',
                'T:standard_name',
                'Pr:units',
                'Pr:standard_name'
            ]),
            output=workspace.forcing(yearmon=yearmon, target=target, member=member)
        )
    ]

def run_b2b(workspace, static, yearmon, target=None, member=None):
    pixel_results = workspace.results(yearmon=yearmon, window=1, target=target, member=member)
    basin_results = workspace.results(yearmon=yearmon, window=1, target=target, member=member, basis='basin')

    return [
        wsim_extract(
            # TODO static.basins().file strips any layer name provided (by file_name::layer_name)
            # TODO should we allow ::layer_name syntax for shapefiles also?
            boundaries=static.basins().file,
            fid="HYBAS_ID",
            input=read_vars(pixel_results, 'RO_m3'),
            output=basin_results,
            stats=['sum'],
            keepvarnames=True
        ).merge(
            wsim_flow(
                input=read_vars(basin_results, 'RO_m3'),
                flowdir=static.basin_downstream(),
                varname='Bt_RO',
                output=basin_results
            )
        )
    ]


def run_lsm(workspace, static, *, yearmon, target=None, member=None, lead_months=0):
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
    forcing = workspace.forcing(yearmon=yearmon, target=target, member=member)

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


def time_integrate(workspace, integrated_stats, *, yearmon, target=None, window=None, member=None, lead_months=None, basis=None):
    months = rolling_window(target if target else yearmon, window)

    if lead_months:
        window_observed = months[:-lead_months]
        window_forecast = months[-lead_months:]
    else:
        window_observed = months
        window_forecast = []

    prev_results = [workspace.results(yearmon=x, window=1, basis=basis) for x in window_observed] + \
                   [workspace.results(yearmon=yearmon, member=member, target=x, window=1, basis=basis) for x in window_forecast]

    return [
        wsim_integrate(
            inputs=[read_vars(f, *set(itertools.chain(*integrated_stats.values()))) for f in prev_results],
            stats=[stat + '::' + ','.join(varname) for stat, varname in integrated_stats.items()],
            attrs=['integration_period=' + str(window)],
            output=workspace.results(yearmon=yearmon, window=window, target=target, member=member, temporary=False, basis=basis)
        )
    ]

def compute_return_periods(workspace, *, forcing_vars=None, result_vars=None, yearmon, window, target=None, member=None, basis=None):
    if target:
        month = int(target[-2:])
    else:
        month = int(yearmon[-2:])

    if forcing_vars is None:
        forcing_vars = []
    if result_vars is None:
        result_vars = []

    args = { 'yearmon' : yearmon, 'target' : target, 'window' : window, 'member' : member, 'basis' : basis }

    if basis:
        assert not forcing_vars

    return [
        wsim_anom(
            fits=[workspace.fit_obs(var=var, window=window, month=month, basis=basis) for var in forcing_vars + result_vars],
            obs=[
                read_vars(workspace.results(**args), *result_vars) if result_vars else None,
                read_vars(workspace.forcing(yearmon=yearmon, target=target, member=member), *forcing_vars) if forcing_vars else None
            ],
            rp=workspace.return_period(**args),
            sa=workspace.standard_anomaly(**args)
        )
    ]


def composite_vars(*, method, window, quantile):
    quantile_text = '_q{}'.format(quantile) if quantile else ''

    if method == 'return_period':
        rp_or_sa = 'rp'
    elif method == 'standard_anomaly':
        rp_or_sa = 'sa'

    if window == 1:
        deficit=[
            'PETmE_{rp_or_sa}{quantile}@fill0@negate->Neg_PETmE',
            'Ws_{rp_or_sa}{quantile}->Ws',
            'Bt_RO_{rp_or_sa}{quantile}->Bt_RO'
        ]
        surplus=[
            'RO_mm_{rp_or_sa}{quantile}->RO_mm',
            'Bt_RO_{rp_or_sa}{quantile}->Bt_RO'
        ]
        mask='Ws_{rp_or_sa}{quantile}'
    else:
        deficit=[
            'PETmE_sum_{rp_or_sa}{quantile}@fill0@negate->Neg_PETmE',
            'Ws_ave_{rp_or_sa}{quantile}->Ws',
            'Bt_RO_sum_{rp_or_sa}{quantile}->Bt_RO'
        ]
        surplus=[
            'RO_mm_sum_{rp_or_sa}{quantile}->RO_mm',
            'Bt_RO_sum_{rp_or_sa}{quantile}->Bt_RO'
        ]
        mask='Ws_ave_{rp_or_sa}{quantile}'

    fmt = lambda x : x.format(quantile=quantile_text, rp_or_sa=rp_or_sa)

    return {
        'deficit' : [fmt(d) for d in deficit],
        'surplus' : [fmt(s) for s in surplus],
        'mask'    : fmt(mask)
    }


def composite_indicators(workspace, *, yearmon, window=None, target=None, quantile=None):
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

def composite_indicator_return_periods(workspace, *, yearmon, window, target=None):
    return [
        wsim_anom(
            fits=[
                workspace.fit_composite_anomalies(window=window, indicator='surplus'),
                workspace.fit_composite_anomalies(window=window, indicator='deficit')
            ],
            obs=read_vars(workspace.composite_anomaly(yearmon=yearmon, window=window, target=target), 'surplus', 'deficit'),
            rp=workspace.composite_anomaly_return_period(yearmon=yearmon, window=window, target=target, temporary=False)
        )
    ]

def composite_indicator_adjusted(workspace, *, yearmon, window, target=None):
    return [
        wsim_composite(
            surplus=[Vardef(workspace.composite_anomaly_return_period(yearmon=yearmon, window=window, target=target), 'surplus_rp').read_as('surplus')],
            deficit=[Vardef(workspace.composite_anomaly_return_period(yearmon=yearmon, window=window, target=target), 'deficit_rp').read_as('deficit')],
            both_threshold=3,
            output=workspace.composite_summary_adjusted(yearmon=yearmon, window=window, target=target),
            clamp=60
        )
    ]

def composite_anomalies(workspace, *, yearmon, window=None, target=None, quantile=None):
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
            both_threshold=0.4307273, # corresponds with rp of 3
            mask=infile + '::' + cvars['mask'],
            output=outfile
        )
    ]


def fit_var(config, *, param, month, stat=None, window=1, basis=None):
    """
    Compute fits for param in given month over fitting period
    """
    yearmons = [t for t in config.result_fit_yearmons()[window-1:] if int(t[-2:]) == month]
    input_range = date_range(yearmons[0], yearmons[-1], 12)

    if stat:
        param_to_read = param + '_' + stat
    else:
        param_to_read = param

    if param in ('T', 'Pr'):
        assert window == 1
        assert basis is None

        infile = config.workspace().forcing(yearmon=input_range)
    else:
        infile = config.workspace().results(yearmon=input_range, window=window, basis=basis)

    # Step for fits
    return [
        wsim_fit(
            distribution=config.distribution,
            inputs=[ read_vars(infile, param_to_read) ],
            output=config.workspace().fit_obs(var=param, stat=stat, month=month, window=window, basis=basis)
        )
    ]


def forcing_summary(workspace, ensemble_members, *, yearmon, target):
    return [
        wsim_integrate(
            inputs=[workspace.forcing(yearmon=yearmon, target=target, member=member) for member in ensemble_members],
            stats=['q25', 'q50', 'q75'],
            output=workspace.forcing_summary(yearmon=yearmon, target=target)
        )
    ]


def result_summary(workspace, ensemble_members, *, yearmon, target, window=None):
    return [
        wsim_integrate(
            inputs=[workspace.results(yearmon=yearmon, window=window, target=target, member=member) for member in ensemble_members],
            stats=['q25', 'q50', 'q75'],
            output=workspace.results_summary(yearmon=yearmon, window=window, target=target)
        )
    ]


def return_period_summary(workspace, ensemble_members, *, yearmon, target, window=None):
    return [
        wsim_integrate(
            inputs=[workspace.return_period(yearmon=yearmon, target=target, window=window, member=member) for member in ensemble_members],
            stats=['q25', 'q50', 'q75'],
            output=workspace.return_period_summary(yearmon=yearmon, window=window, target=target)
        )
    ]


def standard_anomaly_summary(workspace, ensemble_members, *, yearmon, target, window=None):
    return [
        wsim_integrate(
            inputs=[workspace.standard_anomaly(yearmon=yearmon, target=target, window=window, member=member) for member in ensemble_members],
            stats=['q25', 'q50', 'q75'],
            output=workspace.standard_anomaly_summary(yearmon=yearmon, window=window, target=target)
        )
    ]


def correct_forecast(data, *, member, target, lead_months):
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
