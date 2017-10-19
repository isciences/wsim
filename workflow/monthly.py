from commands import *
from step import Step
from dates import get_next_yearmon, days_in_month, rolling_window
from paths import read_vars

def compute_pwetdays(data, yearmon):
    if not hasattr(data, 'precip_daily'):
        return []

    try:
        daily_precip_files = [data.precip_daily(date).file for date in days_in_month(yearmon)]
    except FileNotFoundError:
        print("Can't compute daily precip for", yearmon, "omitting step.")
        return []

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

def create_forcing_file(workspace, data, yearmon, target=None, icm=None):
    if target is None:
        target = yearmon

    if icm:
        precip = data.precip_monthly(target=target, icm=icm)
        temp = data.temp_monthly(target=target, icm=icm)
        wetdays = data.p_wetdays(target=target, icm=icm)
    else:
        precip = data.precip_monthly(yearmon=target)
        temp = data.temp_monthly(yearmon=target)
        wetdays = data.p_wetdays(yearmon=target)

    return [
        Step(
            targets=workspace.forcing(target=target, icm=icm),
            dependencies=[precip.file, temp.file, wetdays.file],
            commands=[
                wsim_merge(
                    inputs=[
                        precip.read_as('Pr'),
                        temp.read_as('T'),
                        wetdays.read_as('pWetDays')
                    ],
                    attrs=filter(None, [
                        'target=' + target,
                        ('icm=' + icm) if icm else None
                    ]),
                    output= '$@'
                )
            ]
        )
    ]

def run_lsm(workspace, static, target, icm=None, lead_months=0):
    is_forecast = True if icm else False

    if is_forecast:
        comment = "Run LSM with forecast data"
    else:
        comment = "Run LSM with observed data"

    current_state = workspace.state(target=target, icm=icm if lead_months > 1 else None)
    next_state = workspace.state(target=get_next_yearmon(target), icm=icm)
    results = workspace.results(target=target, icm=icm)
    forcing = workspace.forcing(target=target, icm=icm)

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

def time_integrate(workspace, window, integrated_vars, target, icm=None, lead_months=None):
    months = rolling_window(target, window)

    if lead_months:
        window_observed = months[:-lead_months]
        window_forecast = months[-lead_months:]
    else:
        window_observed = months
        window_forecast = []

    prev_results = [workspace.results(target=x) for x in window_observed] + \
                   [workspace.results(icm=icm, target=x) for x in window_forecast]

    return [
        Step(
            comment="Time integration of observed results (" + str(window) + " months)",
            targets=workspace.results(target=target, window=window, icm=icm),
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

def compute_return_periods(workspace, window, lsm_vars, integrated_vars, target, icm=None):
    if window is None:
        rp_vars = lsm_vars
    else:
        rp_vars = [var + '_' + stat
                   for var, stats in integrated_vars.items()
                   for stat in stats]

    month = int(target[-2:])

    return [
        Step(
            comment="Observed return periods" + ("(" + str(window) + "mo)" if window is not None else ""),
            targets=workspace.return_period(target=target, window=window, icm=icm),
            dependencies=
                [workspace.fit_obs(var=var, window=window, month=month) for var in rp_vars] +
                [workspace.results(target=target, window=window, icm=icm)],
            commands=[
                wsim_anom(
                    fits=workspace.fit_obs(var=var, window=window, month=month),
                    obs=read_vars(workspace.results(target=target, window=window, icm=icm), var),
                    rp='$@')
                for var in rp_vars
            ]
        )
    ]

def composite_indicators(workspace, window, yearmon, target=None, quantile=None):
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
        infile = workspace.return_period(target=yearmon, window=window)

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
    ensemble_results = [workspace.results(target=target, icm=icm) for icm in ensemble_members]

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
    ensemble_rps = [workspace.return_period(target=target, window=window, icm=icm) for icm in ensemble_members]

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

def monthly_observed(workspace, static, data, integration_windows, integrated_vars, lsm_vars, yearmon):
    steps = []
    # Read daily precipitation files to compute pWetDays
    steps += compute_pwetdays(data, yearmon)

    # Combine forcing data for LSM run
    steps += create_forcing_file(workspace, data, yearmon)

    # Run the LSM
    steps += run_lsm(workspace, static, yearmon)

    # Do time integration
    for window in integration_windows:
        steps += time_integrate(workspace, window, integrated_vars, yearmon)

    # Compute return periods
    for window in [None] + integration_windows:
        steps += compute_return_periods(workspace, window, lsm_vars, integrated_vars, yearmon)

    # Compute composite indicators
    for window in [None] + integration_windows:
        steps += composite_indicators(workspace, window, yearmon)

    return steps

def monthly_forecast(workspace, static, data, integration_windows, integrated_vars, lsm_vars, yearmon, forecast_targets, ensemble_members):
    steps = []

    for i, target in enumerate(forecast_targets):
        lead_months = i+1
        print('Generating steps for', yearmon, 'forecast target', lead_months)
        for icm in ensemble_members:
            # Assemble forcing inputs for forecast
            steps += create_forcing_file(workspace, data, yearmon, target, icm)

            # Run LSM with forecast data
            steps += run_lsm(workspace, static, target, icm, lead_months)

            for window in integration_windows:
                # Time integrate the results
                steps += time_integrate(workspace, window, integrated_vars, target, icm, lead_months)

            for window in [None] + integration_windows:
                # Compute return periods
                steps += compute_return_periods(workspace, window, lsm_vars, integrated_vars, target, icm)

        for window in [None] + integration_windows:
            steps += result_summary(workspace, ensemble_members, yearmon, target, window)
            steps += return_period_summary(workspace, ensemble_members, yearmon, target, window)
            steps += composite_indicators(workspace, window, yearmon, target=target, quantile=50)

    return steps
