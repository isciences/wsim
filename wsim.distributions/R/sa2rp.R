#' Convert standardized anomaly into a return period
#' @param sa vector or RasterLayer of standardized anomalies
sa2rp <- function(sa) {
    if (class(sa) != 'numeric') {
        stop('Non-numeric vector passed to sa2rp')
    }

    R <- sign(sa) / (1 - pnorm(abs(sa)))

    # clip values to +/- 1000
    R <- pmax(-1000, R)
    R <- pmin(1000, R)

    return (R)
}

methods::setGeneric('sa2rp')

methods::setMethod('sa2rp', methods::signature('RasterLayer'), function(sa) {
  raster::setValues(sa, sa2rp(raster::getValues(sa)))
})
