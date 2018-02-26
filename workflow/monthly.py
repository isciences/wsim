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

from actions import *

def monthly_observed(config, yearmon, meta_steps):
    print('Generating steps for', yearmon, 'observed data')

    steps = []

    # Skip if we would already have run this date as part of spinup
    if yearmon in config.historical_yearmons():
        return []

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
        steps += time_integrate(config.workspace(), config.lsm_integrated_vars(), yearmon=yearmon, window=window)

    # Compute return periods
    steps += compute_return_periods(config.workspace(), var_names=config.lsm_rp_vars(), yearmon=yearmon, window=1)
    for window in config.integration_windows():
        steps += compute_return_periods(config.workspace(), var_names=config.lsm_integrated_var_names(), yearmon=yearmon, window=window)

    # Compute composite indicators
    for window in [1] + config.integration_windows():
        composite_indicator_steps = composite_indicators(config.workspace(), window=window, yearmon=yearmon)
        steps += composite_indicator_steps
        steps += composite_anomalies(config.workspace(), window=window, yearmon=yearmon)
        for step in composite_indicator_steps:
            meta_steps['all_composites'] += step.targets
            if window == 1:
                meta_steps['all_monthly_composites'] += step.targets

    return steps

def monthly_forecast(config, yearmon, meta_steps):
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
                steps += time_integrate(config.workspace(), config.lsm_integrated_vars(), window=window, yearmon=yearmon, target=target, member=member, lead_months=lead_months)

            # Compute return periods
            steps += compute_return_periods(config.workspace(), var_names=config.lsm_rp_vars(), yearmon=yearmon, window=1, target=target, member=member)
            for window in config.integration_windows():
                steps += compute_return_periods(config.workspace(), var_names=config.lsm_integrated_var_names(), yearmon=yearmon, window=window, target=target, member=member)

        for window in [1] + config.integration_windows():
            # Summarize forecast ensemble
            steps += result_summary(config.workspace(), config.forecast_ensemble_members(yearmon), yearmon=yearmon, target=target, window=window)
            steps += return_period_summary(config.workspace(), config.forecast_ensemble_members(yearmon), yearmon=yearmon, target=target, window=window)
            steps += standard_anomaly_summary(config.workspace(), config.forecast_ensemble_members(yearmon), yearmon=yearmon, target=target, window=window)

            # Generate composite indicators from summarized ensemble data
            steps += composite_anomalies(config.workspace(), window=window, yearmon=yearmon, target=target, quantile=50)

            composite_indicator_steps = composite_indicators(config.workspace(), window=window, yearmon=yearmon, target=target, quantile=50)
            steps += composite_indicator_steps
            for step in composite_indicator_steps:
                meta_steps['all_composites'] += step.targets
                if window == 1:
                    meta_steps['all_monthly_composites'] += step.targets

    return steps
