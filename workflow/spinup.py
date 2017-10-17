from step import Step
from commands import *
from dates import format_yearmon, get_next_yearmon, all_months
from paths import read_vars, lsm_vars

def spinup(workspace, static_data, observed_data, historical_years, result_fit_years, integration_windows, integrated_vars):
    """
    :param workspace:
    :param static_data :        A data PathFinder for static data
    :param observed_data:       A data PathFinder for observed data
    :param historical_years:    A range of years for which observed data (T, Pr, pWetDays) is available
    :param result_fit_years:    A range of years for which statistical distributions should be fit
    :param integration_windows: A series of integration windows (in months)
    :param integrated_vars:     A dictionary whose keys are LSM output variables to be time-integrated, and whose
                                values are lists of stats to apply to each of those variables (min, max, ave, etc.)
    :return:
    """

    # Produce a map, integrated_stats, that is the inverse
    # of integrated_vars
    integrated_stats = {}
    for var, varstats in integrated_vars.items():
        for stat in varstats:
            if stat not in integrated_stats:
                integrated_stats[stat] = []
            integrated_stats[stat].append(var)

    steps = []
    # Generate a garbage initial state (detention variables set to zero,
    # soil moisture set to 30% of capacity.)
    steps.append(Step(
        targets=workspace.initial_state(),
        dependencies=[],
        commands=[
            # TODO have to remove hardcoded var here..
            wsim_merge(
                inputs=[read_vars(static_data.wc().file,
                                  static_data.wc().var + "@fill0@[0.3*x+1e-5]->Ws",
                                  static_data.wc().var + "@[0]->Dr",
                                  static_data.wc().var + "@[0]->Ds",
                                  static_data.wc().var + "@[0]->Snowpack",
                                  static_data.wc().var + "@[0]->snowmelt_month")],
                attrs=["yearmon=000001"],
                output=workspace.initial_state()
            )
        ]
    ))

    # Read the temperature and precipitation data in our historical range and generate
    # a single "monthly norm" temperature and precipitation file for each month.
    for month in all_months:
        historical_yearmons = [format_yearmon(year, month) for year in historical_years]
        climate_norms = workspace.climate_norms(month=month)

        steps.append(Step(
            targets=workspace.climate_norms(month=month),
            dependencies=[],
            commands=[
                wsim_integrate(
                    inputs=[observed_data.precip_monthly(yearmon=yearmon).read_as('Pr') for yearmon in historical_yearmons],
                    stats=['ave'],
                    output=climate_norms
                ),
                wsim_integrate(
                    inputs=[observed_data.temp_monthly(yearmon=yearmon).read_as('T') for yearmon in historical_yearmons],
                    stats=['ave'],
                    output=climate_norms
                ),
                wsim_integrate(
                    inputs=[observed_data.p_wetdays(yearmon=yearmon).read_as('pWetDays') for yearmon in historical_yearmons],
                    stats=['ave'],
                    output=climate_norms
                )
            ]
        ))

        steps.append(Step(
            targets=workspace.climate_norm_forcing(month=month),
            dependencies=climate_norms,
            commands=[
                wsim_merge(
                    inputs=[read_vars(climate_norms,
                                      'T_ave->T',
                                      'Pr_ave->Pr',
                                      'pWetDays_ave->pWetDays')],
                    output=workspace.climate_norm_forcing(month=month)
                )
            ]
        ))

    # Run the LSM from the garbage initial state using monthly norm forcing
    # for 100 years, discarding the results generated in the process.
    # Store only the final state.
    steps.append(Step(
        targets=workspace.final_state_norms(),
        dependencies=[workspace.climate_norm_forcing(month=month) for month in all_months] + [
            workspace.initial_state()
        ],
        commands=[
            wsim_lsm(
                state=workspace.initial_state(),
                forcing=[workspace.climate_norm_forcing(month=month) for month in all_months],
                elevation=static_data.elevation(),
                flowdir=static_data.flowdir(),
                wc=static_data.wc(),
                results='/dev/null',
                next_state=workspace.final_state_norms(),
                loop=100
            )
        ]
    ))

    historical_forcing = [format_yearmon(year, month)
                          for year in historical_years
                          for month in all_months]

    for yearmon in historical_forcing:
        steps.append(Step(
            targets=workspace.forcing(target=yearmon),
            dependencies=[],
            commands=[
                wsim_merge(
                    inputs=[observed_data.precip_monthly(yearmon=yearmon).read_as('Pr'),
                            observed_data.temp_monthly(yearmon=yearmon).read_as('T'),
                            observed_data.p_wetdays(yearmon=yearmon).read_as('pWetDays')],
                    output=workspace.forcing(target=yearmon)
                )
            ]
        ))

    # Run the LSM over the entire historical period, and retain the state files
    # for each iteration. Discard the results.

    # Making each iteration an individual target is in some ways cleaner and would
    # allow restarting in case of failure. But the runtime becomes dominated by the
    # R startup and I/O, and takes about 5 seconds / iteration instead of 1 second /iteration.
    steps.append(Step(
        targets=[workspace.spinup_state(target=get_next_yearmon(yearmon)) for yearmon in historical_forcing],
        dependencies=[workspace.final_state_norms()] + [workspace.forcing(target=yearmon) for yearmon in historical_forcing],
        commands=[
            # Set the yearmon in final state from climate norms run to be the first
            # forcing date in our historical record
            ['ncatted', '-O', '-a', 'yearmon,global,m,c,"{}"'.format(historical_forcing[0]), workspace.final_state_norms()],
            wsim_lsm(
                forcing=[workspace.forcing(target=yearmon) for yearmon in historical_forcing],
                state=workspace.final_state_norms(),
                elevation=static_data.elevation(),
                flowdir=static_data.flowdir(),
                wc=static_data.wc(),
                results='/dev/null',
                next_state=workspace.spinup_state_pattern()
            )
        ]
    ))

    # Integrate the results from the spinup states to compute monthly norm initial states
    # Discard the first two years
    for month in all_months:
        spinup_states = [workspace.spinup_state(target=format_yearmon(year, month)) for year in [y for y in historical_years][2:]]

        steps.append(Step(
            targets=workspace.spinup_mean_state(month=month),
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
        targets=[workspace.results(target=yearmon) for yearmon in historical_forcing] +
                [workspace.state(target=get_next_yearmon(yearmon)) for yearmon in historical_forcing],
        dependencies=[workspace.spinup_mean_state(month=1)] + [workspace.forcing(target=yearmon) for yearmon in historical_forcing],
        commands=[
            # Set the yearmon in final state from climate norms run to be the first
            # forcing date in our historical record
            # TODO something cleaner than modifying an existing file
            ['ncatted', '-O', '-a', 'yearmon,global,c,c,"{}"'.format(historical_forcing[0]), workspace.spinup_mean_state(month=1)],
            wsim_lsm(
                forcing=[workspace.forcing(target=yearmon) for yearmon in historical_forcing],
                state=workspace.spinup_mean_state(month=1),
                elevation=static_data.elevation(),
                flowdir=static_data.flowdir(),
                wc=static_data.wc(),
                results=workspace.results(target='%T'),
                next_state=workspace.state(target='%T')
            )
        ]
    ))

    all_integrated = [] # for phony
    for window in integration_windows:
        targets = historical_forcing[window-1:]

        # Time-integrate the variables
        inputs = [workspace.results(target=target) for target in historical_forcing]
        outputs = [workspace.results(target=target, window=window) for target in targets]

        all_integrated.append(outputs[-1])
        steps.append(Step(
            comment="Time-integrated historical results: " + str(window) + "mo",
            targets=[workspace.results(target=target, window=window) for target in targets],
            dependencies=inputs,
            commands=[
                wsim_integrate(
                    inputs=[read_vars(f, *integrated_vars.keys()) for f in inputs],
                    window=window,
                    stats=[stat + '::' + ','.join(vars) for stat, vars in integrated_stats.items()],
                    attrs=['integration_period={}'.format(window)],
                    output=outputs
                )
            ]
        ))

    all_fits = []
    # Compute monthly fits over the fit period
    for param in lsm_vars:
        for month in all_months:
            input_files = [workspace.results(target=format_yearmon(year, month)) for year in result_fit_years]

            all_fits.append(workspace.fit_obs(var=param, month=month))

            steps.append(Step(
                targets=[workspace.fit_obs(var=param, month=month)],
                dependencies=input_files,
                commands=[
                    wsim_fit(
                        distribution="gev",
                        inputs=[read_vars(f, param) for f in input_files],
                        output=workspace.fit_obs(var=param, month=month)
                    )
                ]
            ))

    # Compute fits for time-integrated parameters
    fit_targets = [format_yearmon(year, month) for year in result_fit_years for month in all_months]

    for param in integrated_vars.keys():
        for stat in integrated_vars[param]:
            for window in integration_windows:
                for month in all_months:
                    targets = [t for t in fit_targets[window-1:] if int(t[-2:]) == month]

                    input_files = [workspace.results(target=target, window=window) for target in targets]

                    all_fits.append(workspace.fit_obs(var=param, month=month, stat=stat, window=window))

                    steps.append(Step(
                        targets=[workspace.fit_obs(var=param, month=month, stat=stat, window=window)],
                        dependencies=input_files,
                        commands=[
                            wsim_fit(
                                distribution="gev",
                                inputs=[read_vars(f, param + '_' + stat) for f in input_files],
                                output='$@'
                            )
                        ]
                    ))

    # Add a phony target for all fits
    # TODO indicate this as phony
    steps.append(Step(
        targets="all_fits",
        dependencies=all_fits,
        commands=[]
    ))
    steps.append(Step(
        targets="all_integrated",
        dependencies=all_integrated,
        commands=[]
    ))

    return steps
