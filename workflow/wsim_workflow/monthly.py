# Copyright (c) 2018-2022 ISciences, LLC.
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

import datetime

from typing import Dict, List, Optional

from .actions import \
    composite_anomalies, \
    composite_indicator_adjusted, \
    composite_indicator_return_periods, \
    composite_indicators, \
    compute_return_periods, \
    correct_forecast, \
    create_forcing_file,\
    forcing_summary, \
    result_summary, \
    return_period_summary, \
    run_lsm,\
    standard_anomaly_summary, \
    time_integrate
from .polygon_summaries import compute_population_summary
from .config_base import ConfigBase as Config
from .dates import get_lead_months
from .step import Step


def monthly_observed(config: Config, yearmon: str, meta_steps: Dict[str, Step]) -> List[Step]:
    print('Generating steps for', yearmon, config.observed_data().name(), 'observed data')

    steps = []

    # Skip if we would already have run this date as part of spinup
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
            steps += time_integrate(config.workspace(), config.lsm_integrated_stats(), forcing = False, yearmon=yearmon, window=window)
            steps += time_integrate(config.workspace(), config.forcing_integrated_stats(), forcing = True, yearmon=yearmon, window=window)

        # Compute return periods
        for window in [1] + config.integration_windows():
            steps += meta_steps['return_periods'].require(
                    compute_return_periods(config.workspace(),
                        result_vars=config.lsm_rp_vars() if window == 1 else config.lsm_integrated_var_names(),
                        forcing_vars=config.forcing_rp_vars() if window==1 else config.forcing_integrated_var_names(),
                        state_vars=config.state_rp_vars() if window==1 else None,
                        yearmon=yearmon,
                        window=window))

    # Compute composite indicators
    for window in [1] + config.integration_windows():

        # Don't write composite steps for a window that extends back too early.
        if yearmon >= config.historical_yearmons()[window-1]:
            composite_indicator_steps = composite_indicators(config.workspace(), window=window, yearmon=yearmon, mask=config.land_mask())
            steps += composite_indicator_steps

            meta_steps['all_composites'].require(composite_indicator_steps)
            if window == 1:
                meta_steps['all_monthly_composites'].require(composite_indicator_steps)

            if yearmon not in config.historical_yearmons():
                steps += composite_anomalies(config.workspace(), window=window, yearmon=yearmon, mask=config.land_mask())

            # Express composite anomalies in terms of a return period
            # (relative to historical composite anomalies)
            steps += composite_indicator_return_periods(config.workspace(), yearmon=yearmon, window=window)

            # Produce an "adjusted" composite based on the return periods
            # of the composite surface anomaly and composite deficit anomaly
            adjusted_indicator_steps = composite_indicator_adjusted(config.workspace(), yearmon=yearmon, window=window)
            steps += adjusted_indicator_steps

            meta_steps['all_adjusted_composites'].require(adjusted_indicator_steps)
            if window == 1:
                meta_steps['all_adjusted_monthly_composites'].require(adjusted_indicator_steps)

            pop_summary_steps = compute_population_summary(config.workspace(), config.static_data(), yearmon=yearmon, window=window)
            steps += pop_summary_steps
            meta_steps['population_summaries'].require(pop_summary_steps)

    return steps


def monthly_forecast(config: Config,
                     yearmon: str,
                     meta_steps: Dict[str, Step],
                     *, forecast_lag_hours: Optional[int] = None) -> List[Step]:
    steps = []

    if not config.models():
        raise ValueError("Forecast requested for {} iteration but configuration specifies no models. "
                         "Did you want to use --forecasts none?".format(yearmon))

    if not config.forecast_targets(yearmon):
        raise ValueError("Forecast requested for {} iteration but configuration specifies no forecast targets. "
                         "Did you want to use --forecasts none?".format(yearmon))

    for model in config.models():
        if forecast_lag_hours is not None:
            available = len(config.forecast_ensemble_members(model, yearmon, lag_hours=forecast_lag_hours))
            total = len(config.forecast_ensemble_members(model, yearmon))

            if total - available > 0:
                print('Omitting {} prep steps for {} forecasts generated after {}'.format(
                    model,
                    total-available,
                    (datetime.datetime.utcnow() - datetime.timedelta(hours=forecast_lag_hours)).strftime('%Y%m%d%H')))

    for target in config.forecast_targets(yearmon):
        lead_months = get_lead_months(yearmon, target)

        for model in config.models():
            print('Generating steps for', model, yearmon, 'forecast target', target)
            for member in config.forecast_ensemble_members(model, yearmon, lag_hours=forecast_lag_hours):
                if config.should_run_lsm(yearmon):
                    # Prepare the dataset for use (convert from GRIB to netCDF, etc.)
                    steps += meta_steps['prepare_forecasts'].require(
                        config.forecast_data(model).prep_steps(yearmon=yearmon, target=target, member=member))

                    # Bias-correct the forecast
                    steps += meta_steps['prepare_forecasts'].require(
                        correct_forecast(config.forecast_data(model), yearmon=yearmon, member=member, target=target, lead_months=lead_months))

                    # Assemble forcing inputs for forecast
                    steps += meta_steps['prepare_forecasts'].require(
                        create_forcing_file(config.workspace(), config.forecast_data(model),
                                            yearmon=yearmon, target=target, model=model, member=member))

            for member in config.forecast_ensemble_members(model, yearmon):
                if config.should_run_lsm(yearmon):
                    # Run LSM with forecast data
                    steps += run_lsm(config.workspace(), config.static_data(),
                                     yearmon=yearmon, target=target, model=model, member=member, lead_months=lead_months)

                steps += config.result_postprocess_steps(yearmon=yearmon, target=target, model=model, member=member)

                for window in config.integration_windows():
                    # Time integrate the results
                    steps += time_integrate(config.workspace(), config.lsm_integrated_stats(), forcing=False, yearmon=yearmon, window=window, model=model, member=member, target=target)
                    steps += time_integrate(config.workspace(), config.forcing_integrated_stats(), forcing=True, yearmon=yearmon, window=window, model=model, member=member, target=target)

                # Compute return periods
                for window in [1] + config.integration_windows():
                    steps += meta_steps['return_periods'].require(
                            compute_return_periods(config.workspace(),
                                forcing_vars=config.forcing_rp_vars() if window==1 else config.forcing_integrated_var_names(),
                                result_vars=config.lsm_rp_vars() if window==1 else config.lsm_integrated_var_names(),
                                state_vars=config.state_rp_vars() if window==1 else None,
                                yearmon=yearmon,
                                window=window,
                                model=model,
                                target=target,
                                member=member))

        del model

        for window in [1] + config.integration_windows():
            # Summarize forecast ensemble

            # TODO add individual model summaries

            steps += meta_steps['results_summaries'].require(
                result_summary(config, yearmon=yearmon, target=target, window=window))
            steps += meta_steps['forcing_summaries'].require(
                forcing_summary(config, yearmon=yearmon, target=target, window=window))
            steps += meta_steps['return_periods'].require(
                    return_period_summary(config, yearmon=yearmon, target=target, window=window))
            steps += meta_steps['return_periods'].require(
                    standard_anomaly_summary(config, yearmon=yearmon, target=target, window=window))

            # Generate composite indicators from summarized ensemble data
            steps += composite_anomalies(config.workspace(),
                                         window=window, yearmon=yearmon, target=target, quantile=50,
                                         mask=config.land_mask())

            composite_indicator_steps = composite_indicators(config.workspace(),
                                                             window=window, yearmon=yearmon, target=target, quantile=50,
                                                             mask=config.land_mask())
            steps += composite_indicator_steps

            meta_steps['all_composites'].require(composite_indicator_steps)
            if window == 1:
                meta_steps['all_monthly_composites'].require(composite_indicator_steps)

            steps += composite_indicator_return_periods(config.workspace(),
                                                        yearmon=yearmon, window=window, target=target)
            adjusted_indicator_steps = composite_indicator_adjusted(config.workspace(),
                                                                    yearmon=yearmon, window=window, target=target)
            steps += adjusted_indicator_steps

            meta_steps['all_adjusted_composites'].require(adjusted_indicator_steps)
            if window == 1:
                meta_steps['all_adjusted_monthly_composites'].require(adjusted_indicator_steps)

            pop_summary_steps = compute_population_summary(config.workspace(), config.static_data(), yearmon=yearmon, window=window, target=target)
            steps += pop_summary_steps
            meta_steps['population_summaries'].require(pop_summary_steps)

    return steps
