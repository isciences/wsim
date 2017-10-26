from step import Step
from commands import *
from dates import format_yearmon, get_next_yearmon, all_months
from paths import read_vars

from actions import create_forcing_file, compute_pwetdays

def spinup(config):
    """
    Produces the Steps needed to spin up a model from a series
    of observed data files.
    :param config:
    :return:
    """

    # Produce a map, integrated_stats, that is the inverse
    # of integrated_vars
    integrated_stats = {}
    for var, varstats in config.integrated_vars().items():
        for stat in varstats:
            if stat not in integrated_stats:
                integrated_stats[stat] = []
            integrated_stats[stat].append(var)

    steps = []
    # Generate a garbage initial state (detention variables set to zero,
    # soil moisture set to 30% of capacity.)
    steps.append(Step(
        targets=config.workspace().initial_state(),
        dependencies=[],
        commands=[
            # TODO have to remove hardcoded var here..
            wsim_merge(
                inputs=[read_vars(config.static_data().wc().file,
                                  config.static_data().wc().var + "@fill0@[0.3*x+1e-5]->Ws",
                                  config.static_data().wc().var + "@[0]->Dr",
                                  config.static_data().wc().var + "@[0]->Ds",
                                  config.static_data().wc().var + "@[0]->Snowpack",
                                  config.static_data().wc().var + "@[0]->snowmelt_month")],
                attrs=["yearmon=000001"],
                output=config.workspace().initial_state()
            )
        ]
    ))

    # Compute pWetDays for historical period
    for yearmon in config.historical_yearmons():
        steps += compute_pwetdays(config.observed_data(), yearmon)

    # Read the temperature and precipitation data in our historical range and generate
    # a single "monthly norm" temperature and precipitation file for each month.
    for month in all_months:
        historical_yearmons = [format_yearmon(year, month) for year in config.historical_years()]
        climate_norms = config.workspace().climate_norms(month=month)

        input_files = set([config.observed_data().temp_monthly(yearmon=yearmon).file for yearmon in historical_yearmons] +
                          [config.observed_data().precip_monthly(yearmon=yearmon).file for yearmon in historical_yearmons]+
                          [config.observed_data().p_wetdays(yearmon=yearmon).file for yearmon in historical_yearmons])

        steps.append(Step(
            targets=config.workspace().climate_norms(month=month),
            dependencies=list(input_files),
            commands=[
                wsim_integrate(
                    inputs=[config.observed_data().precip_monthly(yearmon=yearmon).read_as('Pr') for yearmon in historical_yearmons],
                    stats=['ave'],
                    output=climate_norms
                ),
                wsim_integrate(
                    inputs=[config.observed_data().temp_monthly(yearmon=yearmon).read_as('T') for yearmon in historical_yearmons],
                    stats=['ave'],
                    output=climate_norms
                ),
                wsim_integrate(
                    inputs=[config.observed_data().p_wetdays(yearmon=yearmon).read_as('pWetDays') for yearmon in historical_yearmons],
                    stats=['ave'],
                    output=climate_norms
                )
            ]
        ))

        steps.append(Step(
            targets=config.workspace().climate_norm_forcing(month=month),
            dependencies=climate_norms,
            commands=[
                wsim_merge(
                    inputs=[read_vars(climate_norms,
                                      'T_ave->T',
                                      'Pr_ave->Pr',
                                      'pWetDays_ave->pWetDays')],
                    output=config.workspace().climate_norm_forcing(month=month)
                )
            ]
        ))

        del historical_yearmons

    # Run the LSM from the garbage initial state using monthly norm forcing
    # for 100 years, discarding the results generated in the process.
    # Store only the final state.
    steps.append(Step(
        targets=config.workspace().final_state_norms(),
        dependencies=[config.workspace().climate_norm_forcing(month=month) for month in all_months] + [
            config.workspace().initial_state()
        ],
        commands=[
            wsim_lsm(
                state=config.workspace().initial_state(),
                forcing=[config.workspace().climate_norm_forcing(month=month) for month in all_months],
                elevation=config.static_data().elevation(),
                flowdir=config.static_data().flowdir(),
                wc=config.static_data().wc(),
                results='/dev/null',
                next_state=config.workspace().final_state_norms(),
                loop=100
            )
        ]
    ))

    for yearmon in config.historical_yearmons():
        steps += create_forcing_file(config.workspace(), config.observed_data(), yearmon)

    # Run the LSM over the entire historical period, and retain the state files
    # for each iteration. Discard the results.
    #
    # Making each iteration an individual target is in some ways cleaner and would
    # allow restarting in case of failure. But the runtime becomes dominated by the
    # R startup and I/O, and takes about 5 seconds / iteration instead of 1 second /iteration.
    steps.append(Step(
        targets=[config.workspace().spinup_state(target=get_next_yearmon(yearmon)) for yearmon in config.historical_yearmons()],
        dependencies=[config.workspace().final_state_norms()] + [config.workspace().forcing(target=yearmon) for yearmon in config.historical_yearmons()],
        commands=[
            # Set the yearmon in final state from climate norms run to be the first
            # forcing date in our historical record
            ['ncatted', '-O', '-a', 'yearmon,global,m,c,"{}"'.format(config.historical_yearmons()[0]), config.workspace().final_state_norms()],
            wsim_lsm(
                forcing=[config.workspace().forcing(target=yearmon) for yearmon in config.historical_yearmons()],
                state=config.workspace().final_state_norms(),
                elevation=config.static_data().elevation(),
                flowdir=config.static_data().flowdir(),
                wc=config.static_data().wc(),
                results='/dev/null',
                next_state=config.workspace().spinup_state_pattern()
            )
        ]
    ))

    # Integrate the results from the spinup states to compute monthly norm initial states
    # Discard the first two years
    for month in all_months:
        spinup_states = [config.workspace().spinup_state(target=format_yearmon(year, month)) for year in [y for y in config.historical_years()][2:]]

        steps.append(Step(
            targets=config.workspace().spinup_mean_state(month=month),
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
        comment="Running LSM from {} to {}".format(config.historical_yearmons()[0], config.historical_yearmons()[-1]),
        targets=[config.workspace().results(target=yearmon) for yearmon in config.historical_yearmons()] +
                [config.workspace().state(target=get_next_yearmon(yearmon)) for yearmon in config.historical_yearmons()],
        dependencies=[config.workspace().spinup_mean_state(month=1)] + [config.workspace().forcing(target=yearmon) for yearmon in config.historical_yearmons()],
        commands=[
            # Set the yearmon in final state from climate norms run to be the first
            # forcing date in our historical record
            # TODO something cleaner than modifying an existing file
            ['ncatted', '-O', '-a', 'yearmon,global,c,c,"{}"'.format(config.historical_yearmons()[0]), config.workspace().spinup_mean_state(month=1)],
            wsim_lsm(
                forcing=[config.workspace().forcing(target=yearmon) for yearmon in config.historical_yearmons()],
                state=config.workspace().spinup_mean_state(month=1),
                elevation=config.static_data().elevation(),
                flowdir=config.static_data().flowdir(),
                wc=config.static_data().wc(),
                results=config.workspace().results(target='%T'),
                next_state=config.workspace().state(target='%T')
            )
        ]
    ))

    all_integrated = [] # for phony
    for window in config.integration_windows():
        targets = config.historical_yearmons()[window-1:]

        # Time-integrate the variables
        inputs = [config.workspace().results(target=target) for target in config.historical_yearmons()]
        outputs = [config.workspace().results(target=target, window=window) for target in targets]

        all_integrated.append(outputs[-1])
        steps.append(Step(
            comment="Time-integrated historical results: " + str(window) + "mo",
            targets=[config.workspace().results(target=target, window=window) for target in targets],
            dependencies=inputs,
            commands=[
                wsim_integrate(
                    inputs=[read_vars(f, *config.integrated_vars().keys()) for f in inputs],
                    window=window,
                    stats=[stat + '::' + ','.join(vars) for stat, vars in integrated_stats.items()],
                    attrs=['integration_period={}'.format(window)],
                    output=outputs
                )
            ]
        ))

    all_fits = []
    # Compute monthly fits over the fit period
    for param in config.lsm_vars():
        for month in all_months:
            input_files = [config.workspace().results(target=format_yearmon(year, month)) for year in config.result_fit_years()]

            all_fits.append(config.workspace().fit_obs(var=param, month=month))

            steps.append(Step(
                targets=[config.workspace().fit_obs(var=param, month=month)],
                dependencies=input_files,
                commands=[
                    wsim_fit(
                        distribution="gev",
                        inputs=[read_vars(f, param) for f in input_files],
                        output=config.workspace().fit_obs(var=param, month=month)
                    )
                ]
            ))

    # Compute fits for time-integrated parameters
    fit_targets = [format_yearmon(year, month) for year in config.result_fit_years() for month in all_months]

    for param in config.integrated_vars().keys():
        for stat in config.integrated_vars()[param]:
            for window in config.integration_windows():
                for month in all_months:
                    targets = [t for t in fit_targets[window-1:] if int(t[-2:]) == month]

                    input_files = [config.workspace().results(target=target, window=window) for target in targets]

                    all_fits.append(config.workspace().fit_obs(var=param, month=month, stat=stat, window=window))

                    steps.append(Step(
                        targets=[config.workspace().fit_obs(var=param, month=month, stat=stat, window=window)],
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
