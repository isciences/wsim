#' Lookup a CDF by distribution name
#'
#' @param distribution name of a statistical distribution
#' @return cumulative distribution function, or NULL if no
#' @export
find_cdf <- function(distribution) {
  dist <- switch(distribution,
         gev=lmom::cdfgev,
         NULL)
  stopifnot(!is.null(dist))
  return(dist)
}
