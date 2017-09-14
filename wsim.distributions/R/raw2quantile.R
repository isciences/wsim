#' Calculate the quantile of a raw forecast
#'
#' Calculate the quantile of a raw forecast relative to retrospective forecasts
#'
#' @param forecast a matrix of forecasted values
#' @param retro_fit a 3D array of GEV fit parameters from retrospective forecasts
#' @return a matrix of quantiles for each observation
raw2quantile <- function(forecast, retro_fit) {
  apply_dist_to_array(retro_fit,
                      forecast,
                      lmom::cdfgev,
                      when.dist.undefined=0.5)
}
