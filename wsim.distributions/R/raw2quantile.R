#' Calculate the quantile of a raw forecast
#'
#' Calculate the quantile of a raw forecast relative to retrospective forecasts
#' @param forecast a Raster* of forecasted values
#' @param GEV a RasterStack of GEV fit parameters
#' @return a Raster* of quantiles for each observation
raw2quantile <- function(forecast, GEV) {
  applyDistToStack(GEV, forecast, lmom::cdfgev, when.dist.undefined=0.5)
}
