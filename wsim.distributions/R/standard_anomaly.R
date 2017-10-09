#' Compute the standard anomaly associated with an observation
#'
#' @param distribution name of distribution used for \code{dist_params}
#' @param dist_params 3D arary of distribution parameters
#' @param obs observed value for which a standard anomaly should be computed
#' @param min.sa minimum value for clamping computed standard anomaly
#' @param max.sa maximum value for clamping computed standard anomaly
#'
#' @return computed standard anomaly
#' @export
standard_anomaly <- function(distribution, dist_params, obs, min.sa=-100, max.sa=100) {

  quantile_fn <- switch(distribution,
                        gev= gev_quantiles,
                        pe3= pe3_quantiles)

  pmin(pmax(stats::qnorm(quantile_fn(obs,
                                     as.matrix(dist_params[,,1]),
                                     as.matrix(dist_params[,,2]),
                                     as.matrix(dist_params[,,3]))), min.sa), max.sa)
}
