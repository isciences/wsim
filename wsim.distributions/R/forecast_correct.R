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

#' forecast_correct
#'
#' Bias-correct a forecast using quantile-matching on computed distributions
#' of retrospective forecasts and observations.
#'
#' @param distribution name of distribution used for \code{retro_fit} and \code{obs_fit}
#' @param forecast A matrix representing forecast values
#' @param retro_fit A 3D array representing GEV distribution parameters
#'                 from retrospective forecasts
#' @param obs_fit A 3D array representing GEV distribution parameters
#'                 from observations
#'
#' @return a matrix with a corrected forecast
#'
#' @useDynLib wsim.distributions, .registration=TRUE
#' @export
forecast_correct <- function(distribution, forecast, retro_fit, obs_fit) {
  extreme_cutoff <- 100
  when_dist_undefined <- 0.5

  correct_fn <- switch(distribution,
                       gev= gev_forecast_correct,
                       pe3= pe3_forecast_correct)

  correct_fn(forecast,
             obs_fit[,,1],
             obs_fit[,,2],
             obs_fit[,,3],
             retro_fit[,,1],
             retro_fit[,,2],
             retro_fit[,,3],
             extreme_cutoff,
             when_dist_undefined)
}
