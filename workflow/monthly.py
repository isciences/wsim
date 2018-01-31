from actions import *

def monthly_observed(config, yearmon):
    print('Generating steps for', yearmon, 'observed data')

    steps = []

    # Don't add LSM steps if we would already have run this date as part of spinup
    if yearmon not in config.historical_yearmons():
        if config.should_run_lsm(yearmon):
            # Prepare the dataset for use (convert from GRIB to netCDF, compute pWetDays, etc.)
            steps += config.observed_data().prep_steps(yearmon=yearmon)

            # Combine forcing data for LSM run
            steps += create_forcing_file(config.workspace(), config.observed_data(), yearmon=yearmon)

            # Run the LSM
            steps += run_lsm(config.workspace(), config.static_data(), yearmon=yearmon)

        steps += config.result_postprocess_steps(yearmon=yearmon)

    # Do time integration
    for window in config.integration_windows():
        steps += time_integrate(config.workspace(), config.integrated_vars(), yearmon=yearmon, window=window)

    # Compute return periods
    for window in [1] + config.integration_windows():
        steps += compute_return_periods(config.workspace(), config.lsm_vars(), config.integrated_vars(), yearmon=yearmon, window=window)

    # Compute composite indicators
    for window in [1] + config.integration_windows():
        steps += composite_indicators(config.workspace(), window=window, yearmon=yearmon)

    return steps

def monthly_forecast(config, yearmon):
    steps = []

    for i, target in enumerate(config.forecast_targets(yearmon)):
        lead_months = i+1
        print('Generating steps for', yearmon, 'forecast target', lead_months)
        for member in config.forecast_ensemble_members(yearmon):
            if config.should_run_lsm(yearmon):
                # Prepare the dataset for use (convert from GRIB to netCDF, etc.)
                steps += config.forecast_data().prep_steps(yearmon=yearmon, target=target, member=member)

                # Bias-correct the forecast
                steps += correct_forecast(config.forecast_data(), member=member, target=target, lead_months=lead_months)

                # Assemble forcing inputs for forecast
                steps += create_forcing_file(config.workspace(), config.forecast_data(), yearmon=yearmon, target=target, member=member)

                # Run LSM with forecast data
                steps += run_lsm(config.workspace(), config.static_data(), yearmon=yearmon, target=target, member=member, lead_months=lead_months)

            steps += config.result_postprocess_steps(yearmon=yearmon, target=target, member=member)

            for window in config.integration_windows():
                # Time integrate the results
                steps += time_integrate(config.workspace(), config.integrated_vars(), window=window, yearmon=yearmon, target=target, member=member, lead_months=lead_months)

            for window in [1] + config.integration_windows():
                # Compute return periods
                steps += compute_return_periods(config.workspace(), config.lsm_vars(), config.integrated_vars(), yearmon=yearmon, window=window, target=target, member=member)

        for window in [1] + config.integration_windows():
            steps += result_summary(config.workspace(), config.forecast_ensemble_members(yearmon), yearmon=yearmon, target=target, window=window)
            steps += return_period_summary(config.workspace(), config.forecast_ensemble_members(yearmon), yearmon=yearmon, target=target, window=window)
            steps += composite_indicators(config.workspace(), window=window, yearmon=yearmon, target=target, quantile=50)

    return steps
