from actions import *

def monthly_observed(config, yearmon):
    print('Generating steps for', yearmon, 'observed data')

    steps = []

    # Prepare the dataset for use (convert from GRIB to netCDF, etc.)
    steps += config.observed_data().prep_steps(yearmon=yearmon)

    # Read daily precipitation files to compute pWetDays
    steps += compute_pwetdays(config.observed_data(), yearmon)

    # Combine forcing data for LSM run
    steps += create_forcing_file(config.workspace(), config.observed_data(), yearmon)

    # Run the LSM
    steps += run_lsm(config.workspace(), config.static_data(), yearmon)

    # Do time integration
    for window in config.integration_windows():
        steps += time_integrate(config.workspace(), window, config.integrated_vars(), yearmon)

    # Compute return periods
    for window in [None] + config.integration_windows():
        steps += compute_return_periods(config.workspace(), window, config.lsm_vars(), config.integrated_vars(), yearmon)

    # Compute composite indicators
    for window in [None] + config.integration_windows():
        steps += composite_indicators(config.workspace(), window, yearmon)

    return steps

def monthly_forecast(config, yearmon):
    steps = []

    for i, target in enumerate(config.forecast_targets(yearmon)):
        lead_months = i+1
        print('Generating steps for', yearmon, 'forecast target', lead_months)
        for icm in config.forecast_ensemble_members(yearmon):
            # Prepare the dataset for use (convert from GRIB to netCDF, etc.)
            steps += config.forecast_data().prep_steps(yearmon=yearmon, target=target, member=icm)

            # Bias-correct the forecast
            steps += correct_forecast(config.forecast_data(), icm, target, lead_months)

            # Assemble forcing inputs for forecast
            steps += create_forcing_file(config.workspace(), config.forecast_data(), yearmon, target, icm)

            # Run LSM with forecast data
            steps += run_lsm(config.workspace(), config.static_data(), target, icm, lead_months)

            for window in config.integration_windows():
                # Time integrate the results
                steps += time_integrate(config.workspace(), window, config.integrated_vars(), target, icm, lead_months)

            for window in [None] + config.integration_windows():
                # Compute return periods
                steps += compute_return_periods(config.workspace(), window, config.lsm_vars(), config.integrated_vars(), target, icm)

        for window in [None] + config.integration_windows():
            steps += result_summary(config.workspace(), config.forecast_ensemble_members(yearmon), yearmon, target, window)
            steps += return_period_summary(config.workspace(), config.forecast_ensemble_members(yearmon), yearmon, target, window)
            steps += composite_indicators(config.workspace(), window, yearmon, target=target, quantile=50)

    return steps
