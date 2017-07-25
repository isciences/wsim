#' forecastCorrect
#'
#' Bias-correct a forecast using quantile-matching on computed distributions
#' of retrospective forecasts and observations.
#'
#' @param A RasterLayer representing forecast values
#' @param retroGEV A RasterStack representing GEV distribution parameters
#'                 from retrospective forecasts
#' @param obsGEV A RasterStack representing GEV distribution parameters
#'                 from observations
#'
#' @return a RasterLayer with a corrected forecast
forecastCorrect <- function(forecast, retroGEV, obsGEV) {
  quantiles <- raw2quantile(forecast, retroGEV)

	# Adjust for values that are not possible to avoid out of range issues.
	# Values can approach limits both because of the value of the forecast
	# and also because of the resampling.

	# Set a value to adjust for extreme values of quantiles
	# Values are rounded to the nearest 4 decimal places to avoid problems
	# with rounding error.
	extreme.cutoff <- 100
	quantiles[quantiles >= (1 - 1/extreme.cutoff) & !is.na(quantiles)] <- round((1 - 1/extreme.cutoff), digits = 4)
	quantiles[quantiles <= (0 + 1/extreme.cutoff) & !is.na(quantiles)] <- round((0 + 1/extreme.cutoff), digits = 4)

  return(quantile2correct(quantiles, obsGEV))
}
