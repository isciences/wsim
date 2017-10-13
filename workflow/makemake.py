from step import Step
from paths import *
from commands import *
from dates import *

#steps = []

vars = {
    #'BINDIR'  : '/home/dbaston/dev/wsim2',
    'BINDIR'  : '/wsim',
    'YEARMON' : '201709',
    'INPUTS'  : '/mnt/fig/WSIM/WSIM_source_V1.2',
    'OUTPUTS' : '.'
}

integrated_vars = {
    'Bt_RO'     : [ 'min', 'max', 'sum' ],
    'Bt_Runoff' : [ 'sum' ],
    'EmPET'     : [ 'sum' ],
    'E'         : [ 'sum' ],
    'PETmE'     : [ 'sum' ],
    'P_net'     : [ 'sum' ],
    #'Pr'        : [ 'sum' ]n
    'RO_mm'     : [ 'sum' ],
    'Runoff_mm' : [ 'sum' ],
    #'Snowpack'  : [ 'sum' ],
    #'T'         : [ 'ave' ],
    'Ws'        : [ 'ave' ]
}

integration_windows = [ 3, 6, 12, 24, 36, 60 ]
historical_years = range(1948, 2017) # the complete historical record
result_fit_years = range(1950, 2010) # the lsm results we want to use for GEV fits
all_months = range(1, 13)

lsm_vars = [
    'Bt_RO',
    'Bt_Runoff',
    'EmPET',
    'PETmE',
    'PET',
    'P_net',
    #    'Pr',
    'RO_m3',
    'RO_mm',
    'Runoff_mm',
    'Runoff_m3',
    'Sa',
    'Sm',
    #    'Snowpack',
    #    'T',
    'Ws'
]

#vars = {
#    'BINDIR'  : '/home/dbaston/dev/wsim2',
#    'YEARMON' : '201709',
#    'INPUTS'  : '/mnt/fig/WSIM/WSIM_source_V1.2',
#    'OUTPUTS' : '/mnt/fig_rw/WSIM_DEV/wsim2'
#}

vars['YEARMON_PREV'] = get_previous_yearmon(vars['YEARMON'])
vars['YEARMON_NEXT'] = get_next_yearmon(vars['YEARMON'])
vars['YEAR'] = vars['YEARMON'][:4]
vars['MONTH'] = vars['YEARMON'][4:]

# Spinup

def spinup():
    steps = []
    # Generate a garbage initial state (detention variables set to zero,
    # soil moisture set to 30% of capacity.)
    steps.append(Step(
        targets=initial_state(),
        dependencies=[],
        commands=[
            wsim_merge(
                inputs=[read_vars(wc(),
                     "1@fill0@[0.3*x+1e-5]->Ws",
                     "1@[0]->Dr",
                     "1@[0]->Ds",
                     "1@[0]->Snowpack",
                     "1@[0]->snowmelt_month")],
                attrs=["yearmon=000001"],
                output=initial_state()
            )
        ]
    ))

    # Read the temperature and precipitation data in our historical range and generate
    # a single "monthly norm" temperature and precipitation file for each month.
    for month in all_months:
        historical_yearmons = [format_yearmon(year, month) for year in historical_years]

        steps.append(Step(
            targets=climate_norms(month=month),
            dependencies=[],
            commands=[
                wsim_integrate(
                    inputs=[read_vars(historical_precip(target=yearmon), '1->Pr') for yearmon in historical_yearmons],
                    stats=['ave'],
                    output=climate_norms(month=month)
                ),
                wsim_integrate(
                    inputs=[read_vars(historical_temp(target=yearmon), '1->T') for yearmon in historical_yearmons],
                    stats=['ave'],
                    output=climate_norms(month=month)
                )
            ]
        ))
        steps.append(Step(
            targets=climate_norm_forcing(month=month),
            dependencies=climate_norms(month=month),
            commands=[
                wsim_merge(
                    inputs=[read_vars(climate_norms(month=month),
                                      'T_ave->T',
                                      'Pr_ave->Pr'),
                            read_vars(wetday_norms(month=month),
                                      '1->pWetDays')],
                    output=climate_norm_forcing(month=month)
                )
            ]
        ))

    # Run the LSM from the garbage initial state using monthly norm forcing
    # for 100 years, discarding the results generated in the process.
    # Store only the final state.
    steps.append(Step(
        targets=final_state_norms(),
        dependencies=[climate_norm_forcing(month=month) for month in all_months] + [
            initial_state()
        ],
        commands=[
            wsim_lsm(
                state=initial_state(),
                forcing=[climate_norm_forcing(month=month) for month in all_months],
                results='/dev/null',
                next_state=final_state_norms(),
                loop=100
            )
        ]
    ))

    historical_forcing = [format_yearmon(year, month)
                          for year in historical_years
                          for month in all_months]

    # Make sure we have forcing data ready for the entire historical period.
    # Since 1979, we have files for pWetDays. Prior to 1979, we rely on
    # precalculated norms.
    for yearmon in historical_forcing:
        year = int(yearmon[:4])
        month = int(yearmon[4:])

        if year < 1979:
            wetday_file = wetday_norms(month=month)
        else:
            wetday_file = historical_wetdays(target=yearmon)

        steps.append(Step(
            targets=forcing(target=yearmon),
            dependencies=[],
            commands=[
                wsim_merge(
                    inputs=[read_vars(historical_precip(target=yearmon), '1->Pr'),
                            read_vars(historical_temp(target=yearmon),   '1->T'),
                            read_vars(wetday_file, '1->pWetDays')],
                    output=forcing(target=yearmon)
                )
            ]
        ))

    # Run the LSM over the entire historical period, and retain the state files
    # for each iteration. Discard the results.

    # Making each iteration an individual target is in some ways cleaner and would
    # allow restarting in case of failure. But the runtime becomes dominated by the
    # R startup and I/O, and takes about 5 seconds / iteration instead of 1 second /iteration.
    steps.append(Step(
        targets=[spinup_state(target=get_next_yearmon(yearmon)) for yearmon in historical_forcing],
        dependencies=[final_state_norms()] + [forcing(target=yearmon) for yearmon in historical_forcing],
        commands=[
            # Set the yearmon in final state from climate norms run to be the first
            # forcing date in our historical record
            ['ncatted', '-O', '-a', 'yearmon,global,m,c,"{}"'.format(historical_forcing[0]), final_state_norms()],
            wsim_lsm(
                forcing=[forcing(target=yearmon) for yearmon in historical_forcing],
                state=final_state_norms(),
                results='/dev/null',
                next_state=spinup_state_pattern()
            )
        ]
    ))

    # Integrate the results from the spinup states to compute monthly norm initial states
    # Discard the first two years
    for month in all_months:
        spinup_states = [spinup_state(target=format_yearmon(year, month)) for year in [y for y in historical_years][2:]]

        steps.append(Step(
            targets=spinup_mean_state(month=month),
            dependencies=spinup_states,
            commands=[
                wsim_integrate(
                    inputs=spinup_states,
                    stats=['ave'],
                    output='$@'
                ),
                ['ncrename',
                 '-vDs_ave,Ds',
                 '-vDr_ave,Dr',
                 '-vWs_ave,Ws',
                 '-vSnowpack_ave,Snowpack',
                 '-vsnowmelt_month_ave,snowmelt_month',
                 '$@'],

            ]
        ))

    # Now run the model for the entire historical record, retaining results and states
    # TODO are the states actually needed for anything?
    steps.append(Step(
        targets=[results(target=yearmon) for yearmon in historical_forcing] +
                [state(target=get_next_yearmon(yearmon)) for yearmon in historical_forcing],
        dependencies=[spinup_mean_state(month=1)] + [forcing(target=yearmon) for yearmon in historical_forcing],
        commands=[
            # Set the yearmon in final state from climate norms run to be the first
            # forcing date in our historical record
            # TODO something cleaner than modifying an existing file
            ['ncatted', '-O', '-a', 'yearmon,global,c,c,"{}"'.format(historical_forcing[0]), spinup_mean_state(month=1)],
            wsim_lsm(
                forcing=[forcing(target=yearmon) for yearmon in historical_forcing],
                state=spinup_mean_state(month=1),
                results=results(target='%T'),
                next_state=state(target='%T')
            )
        ]
    ))


    all_integrated = [] # for phony
    for window in integration_windows:
        targets = historical_forcing[window-1:]

        # Time-integrate the variables
        for target in targets:
            inputs = [results(target=target) for target in rolling_window(target, window)]
            all_integrated.append(results(target=target, window=window))
            steps.append(Step(
                targets=results(target=target, window=window),
                dependencies=inputs,
                commands=[
                    wsim_integrate(
                        inputs=[read_vars(f, var) for f in inputs],
                        stats=stats,
                        attrs=['integration_period={}'.format(window)],
                        output='$@'
                    )
                    for var, stats in integrated_vars.items()
                ]
            ))

    # Compute monthly fits over the fit period
    for param in lsm_vars:
        for month in all_months:
            input_files = [results(target=format_yearmon(year, month)) for year in result_fit_years]

            steps.append(Step(
                targets=[fit_obs(var=param, month=month)],
                dependencies=input_files,
                commands=[
                    wsim_fit(
                        distribution="gev",
                        inputs=[read_vars(f, param) for f in input_files],
                        output=fit_obs(var=param, month=month)
                    )
                ]
            ))

    # Add a phony target for all fits
    # TODO indicate this as phony
    steps.append(Step(
        targets="all_fits",
        dependencies=[fit_obs(var=param, month=month) for month in all_months for param in lsm_vars],
        commands=[]
    ))
    steps.append(Step(
        targets="all_integrated",
        dependencies=all_integrated,
        commands=[]
    ))

    return steps

def monthly():
    steps = []
    # Read daily precipitation files to compute pWetDays
    daily_precip_files = [daily_precip(date) for date in days_in_month(vars['YEARMON'])]
    steps.append(Step(
        targets=wetdays(target=vars['YEARMON']),
        dependencies=daily_precip_files,
        commands=[
            wsim_integrate(
                inputs=[file + '::1@[x-1]->Pr' for file in daily_precip_files],
                stats=['fraction_defined_above_zero'],
                output='$@'
            )
        ]
    ))

    # Combine forcing data for LSM run (observed)
    steps.append(Step(
        targets=forcing(target=vars['YEARMON']),
        dependencies=["{INPUTS}/NCEP/originals/p.{YEARMON}.mon",
                      "{INPUTS}/NCEP/originals/t.{YEARMON}.mon",
                      wetdays(target=vars['YEARMON'])],
        commands=[
            wsim_merge(
                inputs=[
                    '{INPUTS}/NCEP/originals/p.{YEARMON}.mon::1->Pr',
                    '{INPUTS}/NCEP/originals/t.{YEARMON}.mon::1->T',
                    wetdays(target=vars['YEARMON']) + '::Pr_fraction_defined_above_zero->pWetDays'
                ],
                attrs=['YEARMON={YEARMON}'],
                output= '$@'
            )
        ]
    ))

    steps.append(Step(
        comment="Run LSM with observed data",
        targets=[state(target=get_next_yearmon(vars['YEARMON'])),
                 results(target=vars['YEARMON'])],
        dependencies=[forcing(target=vars['YEARMON']),
                      state(target=vars['YEARMON'])], #TODO add static files
        commands=[
            wsim_lsm(
                state=state(target=vars['YEARMON']),
                forcing=forcing(target=vars['YEARMON']),
                results=results(target=vars['YEARMON']),
                next_state=state(target=get_next_yearmon(vars['YEARMON']))
            )
        ]
    ))

    # Do time integration
    for window in integration_windows:
        prev_results = [results(target=yearmo) for yearmo in rolling_window(vars['YEARMON'], window)]

        steps.append(Step(
            comment="Time integration of observed results (" + str(window) + " months)",
            targets=results(target=vars['YEARMON'], window=window),
            dependencies=prev_results,
            commands=[
                wsim_integrate(
                    inputs=[f + '::' + var for f in prev_results],
                    stats=stats,
                    attrs=['integration_period=' + str(window)],
                    output='$@'
                )
                for var, stats in integrated_vars.items()
            ]
        ))

    # Compute return periods
    for window in [None] + integration_windows:
        if window is None:
            rp_vars = lsm_vars
        else:
            rp_vars = [var + '_' + stat
                       for var, stats in integrated_vars.items()
                       for stat in stats]

        steps.append(Step(
            comment="Observed return periods" + ("(" + str(window) + "mo)" if window is not None else ""),
            targets=return_period(target=vars['YEARMON'], window=window),
            dependencies=[results(target=vars['YEARMON'], window=window)],
            commands=[
                wsim_anom(
                    fits=fit_obs(var=var, window=window, month=int(vars['MONTH'])),
                    obs=results(target=vars['YEARMON'], var=var, window=window),
                    rp='$@')
                for var in rp_vars
            ]
        ))

    # TODO add multiple windows
    for window in [None] + integration_windows:
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

        steps.append(Step(
            targets=composite_summary(yearmon=vars['YEARMON'], window=window),
            dependencies=[return_period(target=vars['YEARMON'], window=window)],
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

    # Run LSM with forecast data
    for icm in get_icms(vars['YEARMON']):
        targets = get_forecast_targets(vars['YEARMON'])

        for i in range(len(targets)):
            target = targets[i]
            target_month = target[-2:]
            lead_months = i+1
            forecast_date = icm[:-2]

            # Convert the forecast data from GRIB to netCDF
            steps.append(Step(
                targets=cfs_forecast_raw(icm=icm, target=target),
                dependencies=[cfs_forecast_grib(icm=icm, target=target)],
                commands=[[
                    '{BINDIR}/utils/forecast_convert.sh',
                    '$<',
                    '$@'
                ]]
            ))

            # Bias-correct the forecast
            steps.append(Step(
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
            ))

            # Assemble forcing inputs for forecast
            steps.append(Step(
                targets=forcing(icm=icm, target=target),
                dependencies=[cfs_forecast_corrected(icm=icm, target=target),
                              average_wetdays(month=target_month)],
                commands=[
                    wsim_merge(
                        inputs=[
                            cfs_forecast_corrected(icm=icm, target=target) + '::T,Pr',
                            average_wetdays(month=target_month) + '::1->pWetDays'],
                        output=forcing(icm=icm, target=target))
                ]
            ))

            # Run LSM with forecast data
            steps.append(Step(
                comment="Run LSM with forecast, based on results of previous month's forecast",
                targets=[state(icm=icm, target=get_next_yearmon(target)),
                         results(icm=icm, target=target)],
                dependencies=[forcing(icm=icm, target=target),
                              state(icm=icm if i > 0 else None, target=target)],
                commands=[
                    wsim_lsm(state=state(icm=icm if i > 0 else None, target=target),
                             forcing=forcing(icm=icm, target=target),
                             results=results(icm=icm, target=target),
                             next_state=state(icm=icm, target=get_next_yearmon(target)))
                ]
            ))

            # Time integrate the results
            for window in integration_windows:
                months = rolling_window(target, window)
                window_observed = months[:-(i+1)]
                window_forecast = months[-(i+1):]

                prev_results = [results(target=x) for x in window_observed] + \
                               [results(icm=icm, target=x) for x in window_forecast]

                steps.append(Step(
                    targets=results(icm=icm, target=target, window=window),
                    dependencies=prev_results,
                    commands=[
                        wsim_integrate(
                            inputs=[f + '::' + var for f in prev_results],
                            stats=stats,
                            attrs=['integration_period=' + str(window)],
                            output='$@'
                        )
                        for var, stats in integrated_vars.items()
                    ]
                ))

            # Compute return periods
            for window in [None] + integration_windows:
                rp_vars = [var + '_' + stat
                           for var, stats in integrated_vars.items()
                           for stat in stats]

                steps.append(Step(
                    targets=return_period(target=target, icm=icm, window=window),
                    dependencies=[results(icm=icm, target=target, window=window)],
                    commands=[
                        wsim_anom(
                            fits=fit_obs(var=var, month=target[4:], window=window),
                            obs=results(icm=icm, target=target, window=window, var=var),
                            rp='$@'
                        )
                        for var in rp_vars
                    ]
                ))

    # Summarize ensemble results
    #for target in get_forecast_targets(vars['YEARMON']):
    #    for window in [None] + integration_windows:
    #        ensemble_results = [results(icm=icm, target=target) for icm in get_icms(vars['YEARMON'])]
    #
    #        steps.append(Step(
    #            targets='results_summary_{yearmon}_trgt{target}.nc'.format(yearmon=vars['YEARMON'],
    #                                                                       target=target),
    #            dependencies=ensemble_results,
    #            commands=[
    #                wsim_integrate(
    #                    inputs=ensemble_results,
    #                    stats=['q25', 'q50', 'q75'],
    #                    output='$@'
    #                )
    #            ]
    #        ))

    # Summarize ensemble return periods
    for target in get_forecast_targets(vars['YEARMON']):
        ensemble_rp = [return_period(icm=icm, target=target) for icm in get_icms(vars['YEARMON'])]

        steps.append(Step(
            targets=return_period_summary(yearmon=vars['YEARMON'],
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
    for window in [None] + integration_windows:
        for target in [vars['YEARMON']] + get_forecast_targets(vars['YEARMON']):
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

            if target == vars['YEARMON']:
                rp_in = return_period(target=vars['YEARMON'], window=window)
            else:
                rp_in = return_period_summary(yearmon=vars['YEARMON'], target=target, window=window)

            steps.append(Step(
                targets=composite_summary(yearmon=vars['YEARMON'], window=window),
                dependencies=[],
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

steps = spinup()

import socket
if socket.gethostname() == 'flaxvm':
    print("Checking steps only")
    for step in steps:
        step.get_text(vars)
else:
    with open('/mnt/fig_rw/WSIM_DEV/wsim2/Makefile', 'w') as outfile:
        outfile.write('.DELETE_ON_ERROR:\n')
        outfile.write('.SECONDARY:\n')

        for step in reversed(steps):
            outfile.write(step.get_text(vars))
            step.get_text(vars)

        print("Done")

