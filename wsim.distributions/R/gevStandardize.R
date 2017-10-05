#' @useDynLib wsim.distributions, .registration=TRUE
#' @export
gevStandardize <- function(dist_params, obs) {
   pmin(pmax(stats::qnorm(gev_quantiles(obs,
                                        as.matrix(dist_params[,,1]),
                                        as.matrix(dist_params[,,2]),
                                        as.matrix(dist_params[,,3]))), -100), 100)
}
