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

from paths import read_vars, Vardef
from step import Step
from commands import wsim_integrate, wsim_merge, wsim_anom, wsim_correct, wsim_composite, wsim_lsm
from dates import get_next_yearmon, rolling_window

def create_forcing_file(workspace, data, *, yearmon, target=None, member=None):

    precip = data.precip_monthly(yearmon=yearmon, target=target, member=member)
    temp = data.temp_monthly(yearmon=yearmon, target=target, member=member)
    wetdays = data.p_wetdays(yearmon=yearmon, target=target, member=member)

    return [
        Step(
            comment="Create forcing file",
            targets=workspace.forcing(yearmon=yearmon, target=target, member=member),
            dependencies=[precip.file, temp.file, wetdays.file],
            commands=[
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
                    output= '$@'
                )
            ]
        )
    ]

def run_lsm(workspace, static, *, yearmon, target=None, member=None, lead_months=0):
    is_forecast = True if member else False

    if is_forecast:
        comment = "Run LSM with forecast data"
    else:
        comment = "Run LSM with observed data"


    if is_forecast:
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
        Step(
            comment=comment,
            targets=[
                results,
                next_state
            ],
            dependencies=[
                current_state,
                forcing,
                static.wc().file,
                static.flowdir().file,
                static.elevation().file
            ],
            commands=[
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
        )
    ]

def time_integrate(workspace, integrated_vars, *, yearmon, target=None, window=None, member=None, lead_months=None):
    months = rolling_window(target if target else yearmon, window)

    if lead_months:
        window_observed = months[:-lead_months]
        window_forecast = months[-lead_months:]
    else:
        window_observed = months
        window_forecast = []

    prev_results = [workspace.results(yearmon=x) for x in window_observed] + \
                   [workspace.results(yearmon=yearmon, member=member, target=x) for x in window_forecast]

    return [
        Step(
            comment="Time integration of observed results (" + str(window) + " months)",
            targets=workspace.results(yearmon=yearmon, target=target, window=window, member=member),
            dependencies=prev_results,
            commands=[
                wsim_integrate(
                    inputs=[read_vars(f, var) for f in prev_results],
                    stats=stats,
                    attrs=['integration_period=' + str(window)],
                    output='$@'
                )
                for var, stats in integrated_vars.items()
            ]
        )
    ]

def compute_return_periods(workspace, *, var_names, yearmon, window, target=None, member=None):
    if target:
        month = int(target[-2:])
    else:
        month = int(yearmon[-2:])

    rp_file = workspace.return_period(yearmon=yearmon, target=target, window=window, member=member)
    sa_file = workspace.standard_anomaly(yearmon=yearmon, target=target, window=window, member=member)

    return [
        Step(
            comment="Return periods" + ("(" + str(window) + "mo)" if window is not None else ""),
            targets=[rp_file, sa_file],
            dependencies=
                [workspace.fit_obs(var=var, window=window, month=month) for var in var_names] +
                [workspace.results(yearmon=yearmon, target=target, window=window, member=member)],
            commands=[
                wsim_anom(
                    fits=workspace.fit_obs(var=var, window=window, month=month),
                    obs=read_vars(workspace.results(yearmon=yearmon, target=target, window=window, member=member), var),
                    rp=rp_file,
                    sa=sa_file)
                for var in var_names
            ]
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

    outfile = workspace.composite_summary(yearmon=yearmon, target=target, window=window)

    return [
        Step(
            targets=outfile,
            dependencies=[infile],
            commands=[
                wsim_composite(
                    surplus=[infile + '::' + var for var in cvars['surplus']],
                    deficit=[infile + '::' + var for var in cvars['deficit']],
                    both_threshold=3,
                    mask=infile + '::' + cvars['mask'],
                    output=outfile,
                    clamp=60
                )
            ]
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
        Step(
            targets=outfile,
            dependencies=[infile],
            commands=[
                wsim_composite(
                    surplus=[infile + '::' + var for var in cvars['surplus']],
                    deficit=[infile + '::' + var for var in cvars['deficit']],
                    both_threshold=0.4307273, # corresponds with rp of 3
                    mask=infile + '::' + cvars['mask'],
                    output=outfile
                )
            ]
        )
    ]



def result_summary(workspace, ensemble_members, *, yearmon, target=None, window=None):
    ensemble_results = [workspace.results(yearmon=yearmon, target=target, member=member) for member in ensemble_members]

    return [
        Step(
            targets=workspace.results_summary(yearmon=yearmon, target=target, window=window),
            dependencies=ensemble_results,
            commands=[
                wsim_integrate(
                    inputs=ensemble_results,
                    stats=['q25', 'q50', 'q75'],
                    output='$@'
                )
            ]
        )
    ]

def return_period_summary(workspace, ensemble_members, *, yearmon, target=None, window=None):
    ensemble_rps = [workspace.return_period(yearmon=yearmon, target=target, window=window, member=member) for member in ensemble_members]

    return [
        Step(
            targets=workspace.return_period_summary(yearmon=yearmon, target=target, window=window),
            dependencies=ensemble_rps,
            commands=[
                wsim_integrate(
                    inputs=ensemble_rps,
                    stats=['q25', 'q50', 'q75'],
                    output='$@'
                )
            ]
        )
    ]

def standard_anomaly_summary(workspace, ensemble_members, *, yearmon, target=None, window=None):
    ensemble_anomalies = [workspace.standard_anomaly(yearmon=yearmon, target=target, window=window, member=member) for member in ensemble_members]

    return [
        Step(
            targets=workspace.standard_anomaly_summary(yearmon=yearmon, target=target, window=window),
            dependencies=ensemble_anomalies,
            commands=[
                wsim_integrate(
                    inputs=ensemble_anomalies,
                    stats=['q25', 'q50', 'q75'],
                    output='$@'
                )
            ]
        )
    ]


def correct_forecast(data, *, member, target, lead_months):
    target_month = int(target[-2:])

    return [
        Step(
            targets=data.forecast_corrected(member=member, target=target),
            dependencies=[data.forecast_raw(member=member, target=target)] +
                         [data.fit_retro(target_month=target_month,
                                         lead_months=lead_months,
                                         var=var)
                          for var in ('T', 'Pr')] +
                         [data.fit_obs(month=target_month,
                                       var=var)
                          for var in ('T', 'Pr')],
            commands=[
                wsim_correct(retro=data.fit_retro(target_month=target_month, lead_months=lead_months, var='T'),
                             obs=data.fit_obs(month=target_month, var='T'),
                             forecast=Vardef(data.forecast_raw(member=member, target=target), 'tmp2m@[x-273.15]').read_as('T'),
                             output=data.forecast_corrected(member=member, target=target)),
                wsim_correct(retro=data.fit_retro(target_month=target_month, lead_months=lead_months, var='Pr'),
                             obs=data.fit_obs(month=target_month, var='Pr'),
                             forecast=Vardef(data.forecast_raw(member=member, target=target), 'prate@[x*2628000]').read_as('Pr'),
                             output=data.forecast_corrected(member=member, target=target),
                             append=True)
            ]
        )
    ]

