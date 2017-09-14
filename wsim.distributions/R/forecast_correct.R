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
#' @export
forecast_correct <- function(forecast, retro_fit, obs_fit) {
  quantiles <- raw2quantile(forecast, retro_fit)

	# Adjust for values that are not possible to avoid out of range issues.
	# Values can approach limits both because of the value of the forecast
	# and also because of the resampling.

	# Set a value to adjust for extreme values of quantiles
	# Values are rounded to the nearest 4 decimal places to avoid problems
	# with rounding error.
	extreme.cutoff <- 100
	quantiles[quantiles >= (1 - 1/extreme.cutoff) & !is.na(quantiles)] <- round((1 - 1/extreme.cutoff), digits = 4)
	quantiles[quantiles <= (0 + 1/extreme.cutoff) & !is.na(quantiles)] <- round((0 + 1/extreme.cutoff), digits = 4)

  return(quantile2correct(quantiles, obs_fit))
}
