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
