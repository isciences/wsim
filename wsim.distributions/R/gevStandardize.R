calcSaValue <- function(val, gev.params, min.sa=-100, max.sa=100) {
  if (!any(is.nan(gev.params))) {
    sa <- stats::qnorm(lmom::cdfgev(val, gev.params))
    sa <- max(sa, min.sa)
    sa <- min(sa, max.sa)
    return(sa)
  } else {
    return(NA)
  }
}

#' @export
gevStandardize <- function(dist_params, obs) {
  apply_dist_to_array(dist_params, obs, calcSaValue)
}
