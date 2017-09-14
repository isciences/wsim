#' Apply a function to each pixel of (2,3)D array, passing fit parameters as reference
#'
#' @param dist a (2,3)D array of distribution fit parameters
#' @param obs a (2,3)D array of observation parameters
#' @param fn  A function to apply the distribution to the observations,
#'            when the distribution is defined.  Should have signature
#'            \code{function(values, dist_params)}. The function should return
#'            a vector of the same length for all pixels.
#' @param when.dist.undefined A value to use when the distribution is
#'                            undefined. Length must match the return
#'                            value of \code{fn}.
#' @return a (2,3)D array of values returned by \code{fn}
#'
#' @export
apply_dist_to_array <- function(dist, obs, fn, when.dist.undefined=NA) {
  stopifnot(dim(dist)[1] == dim(obs)[1])
  stopifnot(dim(dist)[2] == dim(obs)[2])

  n_dist <- dim(dist)[[3]]

  combined <- abind::abind(dist, obs, along=3)

  array_apply(combined, function(vals) {
    dist_ij <- vals[1:n_dist]

    if (all(is.na(dist_ij))) {
      return(when.dist.undefined)
    }

    obs_ij <- vals[-(1:n_dist)]

    return(fn(obs_ij, dist_ij))
  })
}
