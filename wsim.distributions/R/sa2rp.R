#' Convert standardized anomaly into a return period
#'
#' @param sa vector or matrix of standardized anomalies
#' @param min.rp minimum value for clamping return period
#' @param max.rp maximum value for clamping return period
#' @return return period
#' @export
sa2rp <- function(sa, min.rp=-1000, max.rp=1000) {
    rp <- sign(sa) / (1 - pnorm(abs(sa)))

    rp <- pmax(rp, min.rp)
    rp <- pmin(rp, max.rp)

    return (rp)
}
