#' forecast_correct
#'
#' Bias-correct a forecast using quantile-matching on computed distributions
#' of retrospective forecasts and observations.
#'
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
forecast_correct <- function(forecast, retro_fit, obs_fit) {
  gev_correct(forecast,
              obs_fit[,,1],
              obs_fit[,,2],
              obs_fit[,,3],
              retro_fit[,,1],
              retro_fit[,,2],
              retro_fit[,,3])
}
