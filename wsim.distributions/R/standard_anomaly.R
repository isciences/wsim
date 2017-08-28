#' Compute the standard anomaly associated with an observation
#'
#' @param cdf_fun cumulative distribution function accepting an observed
#'                value and a vector of distribution parameters as arguments
#' @param dist_params vector of distribution parameters
#' @param obs observed value for which a standard anomaly should be computed
#' @param min.sa minimum value for clamping computed standard anomaly
#' @param max.sa maximum value for clamping computed standard anomaly
#'
#' @return computed standard anomaly
#' @export
standard_anomaly <- function(cdf_fun, dist_params, obs, min.sa=-100, max.sa=100) {
  # TODO change to check is.na also?
  if (!any(is.nan(dist_params))) {
    sa <- stats::qnorm(cdf_fun(obs, para=dist_params))
    # TODO check for NA, NULL, etc on min and max
    sa <- max(sa, min.sa)
    sa <- min(sa, max.sa)
    return(sa)
  } else {
    # return as.numeric(NA) ?
    return(NA)
  }
}
