#' quantile2correct
#'
#' Given the quantile of a forecast and a distribution of observations,
#' produce a corrected forecast by identifying the observed value whose
#' quantile corresponds to the quantile of the forecast.
#'
#' @param quant matrix with quantiles of the forecast to correct
#' @param obs_fit 3D array with parameters for the observed value distribution
#' @return matrix with a corrected forecast
quantile2correct <- function(quant, obs_fit) {
  apply_dist_to_array(obs_fit, quant, function(value, dist_params) {
    if (is.na(value)) {
      return(NA)
    }

    # TODO remove hardcoded index.  Use dist.params$location ?
    if (is.na(dist_params[1])) {
      return(NA)
    }

    # If we lack a complete CDF, return the median.
    if (is.na(dist_params[2])) {
      return(dist_params[1])
    }

    # Use CDF to match quantiles
    return (lmom::quagev(value, dist_params))
  })
}
