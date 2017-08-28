#' Convert standardized anomaly into a return period
#'
#' @param sa vector or RasterLayer of standardized anomalies
#' @param min.rp minimum value for clamping return period
#' @param max.rp maximum value for clamping return period
#' @return return period
#' @export
sa2rp <- function(sa, min.rp=-1000, max.rp=1000) {
    rp <- sign(sa) / (1 - pnorm(abs(sa)))

    rp <- pmax(min.rp, rp)
    rp <- pmin(max.rp, rp)

    return (rp)
}

methods::setGeneric('sa2rp')

methods::setMethod('sa2rp', methods::signature('RasterLayer'), function(sa) {
  raster::setValues(sa, sa2rp(raster::getValues(sa)))
})
