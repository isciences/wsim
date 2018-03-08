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

from commands import *
from dates import format_yearmon, all_months, get_next_yearmon
from paths import read_vars, date_range

from actions import create_forcing_file, compute_return_periods, composite_anomalies

def spinup(config, meta_steps):
    """
    Produces the Steps needed to spin up a model from a series
    of observed data files.
    """
    steps = []
    all_fits = meta_steps['all_fits']

    if config.should_run_lsm():
        print("Adding spinup LSM runs")

        steps += generate_garbage_state(config)
        steps += compute_climate_norms(config)
        steps += run_lsm_with_monthly_norms(config, years=100)

        for yearmon in config.historical_yearmons():
            steps += config.observed_data().prep_steps(yearmon=yearmon)
            steps += create_forcing_file(config.workspace(), config.observed_data(), yearmon=yearmon)

        steps += run_lsm_from_final_norm_state(config)

        for month in all_months:
            steps += mean_spinup_state(config, month, list(config.historical_years())[2:])

        steps += run_lsm_from_mean_spinup_state(config)

    for yearmon in config.historical_yearmons():
        steps += config.result_postprocess_steps(yearmon=yearmon)

    # Time-integrate the variables
    for window in config.integration_windows():
        steps += time_integrate_results(config, window)

    # Compute monthly fits (and then anomalies) over the fit period
    for param in config.lsm_rp_vars():
        for month in all_months:
            steps += all_fits.require(fit_var(config, param=param, month=month))

    # Compute fits for time-integrated parameters
    for param in config.lsm_integrated_vars().keys():
        for stat in config.lsm_integrated_vars()[param]:
            for window in config.integration_windows():
                for month in all_months:
                    steps += all_fits.require(fit_var(config, param=param, stat=stat, month=month, window=window))

    # Steps for anomalies and composite anomalies
    for window in [1] + config.integration_windows():
        for yearmon in config.result_fit_yearmons()[window-1:]:
            steps += compute_return_periods(config.workspace(),
                                            var_names=config.lsm_rp_vars() if window == 1 else config.lsm_integrated_var_names(),
                                            yearmon=yearmon,
                                            window=window)

            steps += composite_anomalies(config.workspace(),
                                         yearmon=yearmon,
                                         window=window)

    # Fit distribution of composite anomalies
    for window in [1] + config.integration_windows():
        steps += fit_composite_anomalies(config, window=window)

    return steps

def generate_garbage_state(config):
    """
    Generate a "garbage" initial state with detention variables set to zero
    and soil moisture at 30% of capacity
    """
    return [
        wsim_merge(
            inputs=[read_vars(config.static_data().wc().file,
                              config.static_data().wc().var + "@fill0@[0.3*x+1e-5]->Ws",
                              config.static_data().wc().var + "@[0]->Dr",
                              config.static_data().wc().var + "@[0]->Ds",
                              config.static_data().wc().var + "@[0]->Snowpack",
                              config.static_data().wc().var + "@[0]->snowmelt_month")],
            attrs=[
                "yearmon=000001",
                "Ws:units=mm",
                "Dr:units=mm",
                "Ds:units=mm",
                "Snowpack:units=mm"
            ],
            output=config.workspace().initial_state()
        )
    ]

def compute_climate_norms(config):
    """
    Read forcing data for the full historical range and generate a set of
    twelve "monthly norm" forcing files.
    """
    steps = []

    for month in all_months:
        historical_yearmons = [format_yearmon(year, month) for year in config.historical_years()]

        steps.append(
            wsim_integrate(
                inputs=[config.observed_data().precip_monthly(yearmon=yearmon).read_as('Pr') for yearmon in historical_yearmons],
                stats=['ave'],
                keepvarnames=True,
                output=config.workspace().climate_norm_forcing(month=month, temporary=True)
            ).merge(
            wsim_integrate(
                inputs=[config.observed_data().temp_monthly(yearmon=yearmon).read_as('T') for yearmon in historical_yearmons],
                stats=['ave'],
                keepvarnames=True,
                output=config.workspace().climate_norm_forcing(month=month, temporary=True)
            )).merge(
            wsim_integrate(
                inputs=[config.observed_data().p_wetdays(yearmon=yearmon).read_as('pWetDays') for yearmon in historical_yearmons],
                stats=['ave'],
                keepvarnames=True,
                output=config.workspace().climate_norm_forcing(month=month, temporary=True)
            )).merge(
            move(
                config.workspace().climate_norm_forcing(month=month, temporary=True),
                config.workspace().climate_norm_forcing(month=month, temporary=False)
            ))
        )

    return steps

def run_lsm_with_monthly_norms(config, *, years):
    """
    Run the LSM from the garbage initial state using monthly norm forcing
    for 100 years, discarding the results generated in the process.
    Store only the final state.
    """
    return [
        wsim_lsm(
            state=config.workspace().initial_state(),
            forcing=[config.workspace().climate_norm_forcing(month=month) for month in all_months],
            elevation=config.static_data().elevation(),
            flowdir=config.static_data().flowdir(),
            wc=config.static_data().wc(),
            results='/dev/null',
            next_state=config.workspace().final_state_norms(),
            loop=years
        )
    ]

def run_lsm_from_final_norm_state(config):
    """
    Run the LSM over the entire historical period, and retain the state files
    for each iteration. Discard the results.
    """

    # Set the yearmon in final state from climate norms run to be the first
    # forcing date in our historical record
    initial_yearmon=config.historical_yearmons()[0]

    make_initial_state = Step(
        targets=config.workspace().spinup_state(yearmon=initial_yearmon),
        dependencies=config.workspace().final_state_norms(),
        commands=[
            [
                'ncatted',
                '-a', 'yearmon,global,m,c,"{}"'.format(initial_yearmon),
                config.workspace().final_state_norms(),
                config.workspace().spinup_state(yearmon=initial_yearmon)
            ]
        ]
    )

    # Making each iteration an individual target is in some ways cleaner and would
    # allow restarting in case of failure. But the runtime becomes dominated by the
    # R startup and I/O, and takes about 5 seconds / iteration instead of 1 second /iteration.
    run_lsm = wsim_lsm(
        forcing=[config.workspace().forcing(yearmon=date_range(config.historical_yearmons()))],
        state=config.workspace().spinup_state(yearmon=initial_yearmon),
        elevation=config.static_data().elevation(),
        flowdir=config.static_data().flowdir(),
        wc=config.static_data().wc(),
        results='/dev/null',
        next_state=config.workspace().spinup_state_pattern()
    ).replace_targets_with_tag_file(config.workspace().tag('spinup_from_climate_norm_final_state'))

    return [
        make_initial_state,
        run_lsm
    ]

def mean_spinup_state(config, month, years):
    """
    Average the values from spinup states for "month" over "years"
    """
    spinup_states = [config.workspace().spinup_state(yearmon=format_yearmon(year, month)) for year in years]

    return [
        wsim_integrate(
            inputs=spinup_states,
            stats=['ave'],
            output=config.workspace().spinup_mean_state(month=month),
            keepvarnames=True
        ).replace_dependencies(config.workspace().tag('spinup_from_climate_norm_final_state'))
    ]

def run_lsm_from_mean_spinup_state(config):
    """
    Run the model for the entire historical period, retaining results and states
    """
    first_timestep = config.historical_yearmons()[0]
    first_month = int(first_timestep[4:])

    make_initial_state = Step(
        comment="Create initial state file",
        targets=config.workspace().state(yearmon=first_timestep),
        dependencies=config.workspace().spinup_mean_state(month=first_month),
        commands=[
            [
                'ncatted',
                '-a'
                'yearmon,global,c,c,"{}"'.format(first_timestep),
                config.workspace().spinup_mean_state(month=first_month),
                config.workspace().state(yearmon=first_timestep)
            ]
        ]
    )

    run_lsm = wsim_lsm(
        comment="LSM run from mean spinup state",
        forcing=[config.workspace().forcing(yearmon=date_range(config.historical_yearmons()))],
        state=config.workspace().state(yearmon=first_timestep),
        elevation=config.static_data().elevation(),
        flowdir=config.static_data().flowdir(),
        wc=config.static_data().wc(),
        results=config.workspace().results(window=1, yearmon='%T'),
        next_state=config.workspace().state(yearmon='%T')
    )

    tag_steps = create_tag(name=config.workspace().tag('spinup_1mo_results'),
                           dependencies=[config.workspace().results(window=1, yearmon=y) for y in config.historical_yearmons()] + \
                                        [config.workspace().state(yearmon=get_next_yearmon(y)) for y in config.historical_yearmons()])
    run_lsm.replace_targets_with_tag_file(config.workspace().tag('spinup_1mo_results'))

    return [
        make_initial_state,
        run_lsm,
        *tag_steps
    ]

def time_integrate_results(config, window):
    """
    Integrate all LSM results with the given time window
    """
    yearmons_in = config.result_fit_yearmons()
    yearmons_out = yearmons_in[window-1:]

    integrate = wsim_integrate(
        inputs=read_vars(config.workspace().results(window=1, yearmon=date_range(yearmons_in)),
                         *config.lsm_integrated_vars().keys()),
        window=window,
        stats=[stat + '::' + ','.join(varname) for stat, varname in config.lsm_integrated_stats().items()],
        attrs=['integration_period={}'.format(window)],
        output=config.workspace().results(yearmon=date_range(yearmons_out),
                                          window=window)
    )

    tag_name = config.workspace().tag('spinup_{}mo_results'.format(window))

    tag_steps = create_tag(name=tag_name, dependencies=integrate.targets)

    integrate.replace_targets_with_tag_file(tag_name)
    integrate.replace_dependencies(config.workspace().tag('spinup_1mo_results'))

    return [
        integrate,
        *tag_steps
    ]

def fit_var(config, *, param, month, stat=None, window=1):
    """
    Compute fits for param in given month over fitting period
    """
    yearmons = [t for t in config.result_fit_yearmons()[window-1:] if int(t[-2:]) == month]

    if stat:
        param_to_read = param + '_' + stat
    else:
        param_to_read = param

    # Step for fits
    return [
        wsim_fit(
            distribution=config.distribution,
            inputs=[
                read_vars(
                    config.workspace().results(yearmon=date_range(yearmons[0], yearmons[-1], 12), window=window),
                    param_to_read)
            ],
            output=config.workspace().fit_obs(var=param, stat=stat, month=month, window=window)
        )
    ]

def fit_composite_anomalies(config, *, window):
    fit_yearmons = config.result_fit_yearmons()[window-1:]

    return [
        wsim_fit(
            distribution=config.distribution,
            inputs=[
                read_vars(config.workspace().composite_anomaly(yearmon=date_range(fit_yearmons[0], fit_yearmons[-1]), window=window), indicator)
            ],
            output=config.workspace().fit_composite_anomalies(indicator=indicator, window=window)
        )
        for indicator in ('surplus', 'deficit')
    ]
