from commands import *
from step import Step
from dates import get_next_yearmon, days_in_month, rolling_window
from paths import read_vars

def compute_pwetdays(data, yearmon):
    if not hasattr(data, 'precip_daily'):
        return []

    daily_precip_files = [data.precip_daily(date).file for date in days_in_month(yearmon)]

    return [
        Step(
            targets=data.wetdays(target=yearmon).file,
            dependencies=daily_precip_files,
            commands=[
                wsim_integrate(
                    # TODO need to remove hardcode of band 1
                    inputs=[file + '::1@[x-1]->Pr' for file in daily_precip_files],
                    stats=['fraction_defined_above_zero'],
                    output='$@'
                )
            ]
        )
    ]

def create_forcing_file(workspace, data, yearmon, target=None, icm=None):
    if target is None:
        target = yearmon

    precip = data.precip_monthly(yearmon=target, icm=icm)
    temp = data.temp_monthly(yearmon=target, icm=icm)
    wetdays = data.p_wetdays(yearmon=target, icm=icm)

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

def run_lsm(workspace, static, target, icm=None):
    is_forecast = True if icm else False

    if is_forecast:
        comment = "Run LSM with forecast data"
    else:
        comment = "Run LSM with observed data"

    current_state = workspace.state(target=target, icm=icm)
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
            targets=workspace.results(target=target, window=window),
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
            dependencies=[workspace.results(target=target, window=window, icm=icm)],
            commands=[
                wsim_anom(
                    fits=workspace.fit_obs(var=var, window=window, month=month),
                    obs=workspace.results(target=target, var=var, window=window),
                    rp='$@')
                for var in rp_vars
            ]
        )
    ]

def composite_indicators(workspace, window, yearmon):
    if window is None:
        surplus=[
            '$<::PETmE_rp@fill0@negate->Neg_PETmE',
            '$<::Ws_rp->Ws',
            '$<::Bt_RO_rp->Bt_RO'
        ]
        deficit=[
            '$<::RO_mm_rp->RO_mm',
            '$<::Bt_RO_rp->Bt_RO'
        ]
        mask='$<::Ws_rp'
    else:
        surplus=[
            '$<::PETmE_sum_rp@fill0@negate->Neg_PETmE',
            '$<::Ws_ave_rp->Ws',
            '$<::Bt_RO_sum_rp->Bt_RO'
        ]
        deficit=[
            '$<::RO_mm_sum_rp->RO_mm',
            '$<::Bt_RO_sum_rp->Bt_RO'
        ]
        mask='$<::Ws_ave_rp'

    return [
        Step(
            targets=workspace.composite_summary(yearmon=yearmon, window=window),
            dependencies=[workspace.return_period(target=yearmon, window=window)],
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

def convert_forecast(icm, target):
    return [
        Step(
            targets=cfs_forecast_raw(icm=icm, target=target),
            dependencies=[cfs_forecast_grib(icm=icm, target=target)],
            commands=[
                forecast_convert('$<', '$@')
            ]
        )
    ]

def correct_forecast(icm, target, lead_months):
    target_month = target[-2:]

    return [
        Step(
            targets=cfs_forecast_corrected(icm=icm, target=target),
            dependencies=[cfs_forecast_raw(icm=icm, target=target)] +
                         [fit_retro(target_month=target_month,
                                    lead_months=lead_months,
                                    var=var)
                          for var in ('T', 'Pr')] +
                         [fit_obs(target_month=target_month,
                                  var=var)
                          for var in ('T', 'Pr')],
            commands=[
                wsim_correct(retro=fit_retro(target_month=target_month, lead_months=lead_months, var='T'),
                             obs=fit_obs(target_month=target_month, var='T'),
                             forecast=cfs_forecast_raw(icm=icm, target=target) + '::tmp2m->T',
                             output=cfs_forecast_corrected(icm=icm, target=target)),
                wsim_correct(retro=fit_retro(target_month=target_month, lead_months=lead_months, var='Pr'),
                             obs=fit_obs(target_month=target_month, var='Pr'),
                             forecast=cfs_forecast_raw(icm=icm, target=target) + '::prate->Pr',
                             output=cfs_forecast_corrected(icm=icm, target=target),
                             append=True)
            ]
        )
    ]

def monthly_forecast(workspace, static, data, integration_windows, integrated_vars, yearmon, forecast_targets, ensemble_members):
    steps = []

    for i, target in enumerate(forecast_targets):
        lead_months = i+1

        for icm in ensemble_members:
            # Convert the forecast data from GRIB to netCDF
            steps += convert_forecast(icm, target)

            # Bias-correct the forecast
            steps += correct_forecast(icm, target, lead_months)

            # Assemble forcing inputs for forecast
            steps += create_forcing_file(workspace, data, yearmon, target, icm)

            # Run LSM with forecast data
            steps += run_lsm(workspace, static, target, icm)

            for window in [None] + integration_windows:
                # Time integrate the results
                steps += time_integrate(workspace, window, integrated_vars, target, icm)

                # Compute return periods
                steps += compute_return_periods(workspace, window, lsm_vars, integrated_vars, target, icm)

        for window in [None] + integration_windows:
            ensemble_results = [workspace.results(target=target, icm=icm) for icm in ensemble_members]
            ensemble_rp = [workspace.return_period(target=target, icm=icm) for icm in ensemble_members]

            steps.append(Step(
                targets='results_summary_{yearmon}_{window}mo_trgt{target}.nc'.format(yearmon=vars['YEARMON'],
                                                                           target=target),
                dependencies=ensemble_results,
                commands=[
                    wsim_integrate(
                        inputs=ensemble_results,
                        stats=['q25', 'q50', 'q75'],
                        output='$@'
                    )
                ]
            ))

            # Summarize ensemble return periods
            steps.append(Step(
                targets=return_period_summary(yearmon=yearmon,
                                              target=target),
                dependencies=ensemble_rp,
                commands=[
                    wsim_integrate(
                        inputs=ensemble_rp,
                        stats=['q25', 'q50', 'q75'],
                        output='$@'
                    )
                ]
            ))

            # Generate composite indicators
            if window is None:
                surplus=[
                    '$<::PETmE_rp@fill0@negate->Neg_PETmE',
                    '$<::Ws_rp->Ws',
                    '$<::Bt_RO_rp->Bt_RO'
                ]
                deficit=[
                    '$<::RO_mm_rp->RO_mm',
                    '$<::Bt_RO_rp->Bt_RO'
                ]
                mask='$<::Ws_rp'
            else:
                surplus=[
                    '$<::PETmE_sum_rp@fill0@negate->Neg_PETmE',
                    '$<::Ws_ave_rp->Ws',
                    '$<::Bt_RO_sum_rp->Bt_RO'
                ]
                deficit=[
                    '$<::RO_mm_sum_rp->RO_mm',
                    '$<::Bt_RO_sum_rp->Bt_RO'
                ]
                mask='$<::Ws_ave_rp'

            if target == yearmon:
                rp_in = return_period(target=yearmon, window=window)
            else:
                rp_in = return_period_summary(yearmon=yearmon, target=target, window=window)

            steps.append(Step(
                targets=composite_summary(yearmon=yearmon, window=window),
                dependencies=[rp_in],
                commands=[
                    wsim_composite(
                        surplus=surplus,
                        deficit=deficit,
                        both_threshold=3,
                        mask=mask,
                        output='$@'
                    )
                ]
            ))

            #if True:
            #    # Generate composite indicators (observed)
            #    deficit_vars = [
            #        'PETmE_rp@fill0@negate->Neg_PETmE',
            #        'Ws_ave_rp->Ws',
            #        'Bt_RO_rp->Bt_RO'
            #    ]
            #
            #    surplus_vars = [
            #        'Bt_RO_rp->Bt_RO',
            #        'RO_mm_rp->RO_mm'
            #    ]
            #
            #    steps.append(Step(
            #        targets=composite_summary(yearmon=vars['YEARMON']),
            #        dependencies=return_period(target=vars['YEARMON']),
            #        commands=[
            #            wsim_composite(
            #                surplus=[return_period(target=vars['YEARMON']) + '::' + ','.join(surplus_vars)],
            #                deficit=[return_period(target=vars['YEARMON']) + '::' + ','.join(deficit_vars)],
            #                mask=return_period(target=vars['YEARMON']) + '::Ws_ave_rp',
            #                both_threshold=3,
            #                output='$@'
            #            )
            #        ]
            #
            #    ))

