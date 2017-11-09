from paths import read_vars, Vardef
from step import Step
from commands import wsim_integrate, wsim_merge, wsim_anom, wsim_correct, wsim_composite, wsim_fit, wsim_lsm
from dates import days_in_month, get_next_yearmon, rolling_window

def compute_pwetdays(data, yearmon):
    if not hasattr(data, 'precip_daily'):
        return []

    try:
        daily_precip_files = [data.precip_daily(date).file for date in days_in_month(yearmon)]

        return [
            Step(
                targets=data.p_wetdays(yearmon=yearmon).file,
                dependencies=daily_precip_files,
                commands=[
                    wsim_integrate(
                        # TODO need to remove hardcode of band 1
                        inputs=[file + '::1@[x-1]->Pr' for file in daily_precip_files],
                        stats=['fraction_defined_above_zero'],
                        output='$@'
                    ),
                    ['ncrename', '-O', '-vPr_fraction_defined_above_zero,pWetDays', '$@']
                ]
            )
        ]

    except FileNotFoundError:
        print("Can't compute daily precip for", yearmon, ", omitting step.")
        return []


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
                        ('member=' + member) if member else None
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

    results = workspace.results(yearmon=yearmon, target=target, member=member)
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
                #static.wc().file,
                #static.flowdir().file,
                #static.elevation().file
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

def time_integrate(workspace, integrated_vars, yearmon=None, target=None, window=None, member=None, lead_months=None):
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

def compute_return_periods(workspace, lsm_vars, integrated_vars, *, yearmon, window=None, target=None, member=None):
    if window is None:
        rp_vars = lsm_vars
    else:
        rp_vars = [var + '_' + stat
                   for var, stats in integrated_vars.items()
                   for stat in stats]

    if target:
        month = int(target[-2:])
    else:
        month = int(yearmon[-2:])

    return [
        Step(
            comment="Return periods" + ("(" + str(window) + "mo)" if window is not None else ""),
            targets=workspace.return_period(yearmon=yearmon, target=target, window=window, member=member),
            dependencies=
            [workspace.fit_obs(var=var, window=window, month=month) for var in rp_vars] +
            [workspace.results(yearmon=yearmon, target=target, window=window, member=member)],
            commands=[
                wsim_anom(
                    fits=workspace.fit_obs(var=var, window=window, month=month),
                    obs=read_vars(workspace.results(yearmon=yearmon, target=target, window=window, member=member), var),
                    rp='$@')
                for var in rp_vars
            ]
        )
    ]

def composite_indicators(workspace, window=None, yearmon=None, target=None, quantile=None):
    q = '_q{quantile}'.format(quantile=quantile) if quantile else ''

    if window is None:
        deficit=[
            '$<::PETmE_rp' + q + '@fill0@negate->Neg_PETmE',
            '$<::Ws_rp' + q +'->Ws',
            '$<::Bt_RO_rp' + q +'->Bt_RO'
        ]
        surplus=[
            '$<::RO_mm_rp' + q + '->RO_mm',
            '$<::Bt_RO_rp' + q + '->Bt_RO'
        ]
        mask='$<::Ws_rp' + q
    else:
        surplus=[
            '$<::PETmE_sum_rp' + q + '@fill0@negate->Neg_PETmE',
            '$<::Ws_ave_rp' + q + '->Ws',
            '$<::Bt_RO_sum_rp' + q + '->Bt_RO'
        ]
        deficit=[
            '$<::RO_mm_sum_rp' + q + '->RO_mm',
            '$<::Bt_RO_sum_rp' + q + '->Bt_RO'
        ]
        mask='$<::Ws_ave_rp' + q

    if target:
        infile = workspace.return_period_summary(yearmon=yearmon, target=target, window=window)
    else:
        infile = workspace.return_period(yearmon=yearmon, window=window)

    return [
        Step(
            targets=workspace.composite_summary(yearmon=yearmon, target=target, window=window),
            dependencies=[infile],
            commands=[
                wsim_composite(
                    surplus=surplus,
                    deficit=deficit,
                    both_threshold=3,
                    mask=mask,
                    output='$@'
                )
            ]
        )
    ]

def result_summary(workspace, ensemble_members, yearmon, target, window):
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

def return_period_summary(workspace, ensemble_members, yearmon, target, window):
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

def correct_forecast(data, member, target, lead_months):
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

