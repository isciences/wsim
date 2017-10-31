#' Use L-moments to fit a GEV against observations in an array.
#'
#' If the observed data at a a pixel contains an insufficient number of
#' defined values, then all distribution parameters at that pixel will
#' be undefined.
#'
#' If the observed data at a pixel contains a a sufficient number of
#' defined values, but an insufficient number of unique values, then the
#' location parameter at that pixel will be set to the median of the
#' defined values and the other parameters will remain undefined.
#'
#' If a GEV distribution cannot be fit, then the returned parameters will
#' be NA.  (TODO: why would this happen?  See "try" call in code).
#'
#' @param arr A 3D array representing multiple observations of a variable
#'            at eahc pixel
#' @param nmin.unique Minimum number of unique values required to perform
#'        the fit
#' @param nmin.defined Minimum number of defined values required to perform
#'        the fit
#' @param zero.scale.to.na If TRUE, fit will be discarded (set to NA) if
#'        the scale parameter is computed to be zero.
#'
#' @return A 3D array containing the fitted (location, scale, shape)
#'         parameters of the GEV for each pixel
#'
#' @export
fitGEV <- function(arr, nmin.unique=10, nmin.defined=10, zero.scale.to.na=TRUE) {
  gev.params  <- c("location", "scale", "shape")

  gev_work <- function(pvals) {
      # Figure whether the pixel is missing more than nmin values.
      enough.defined <- sum(!is.na(pvals)) >= nmin.defined

      # Figure whether the pixel has enough unique values
      enough.unique <- length(stats::na.omit(unique(pvals))) >= nmin.unique

      ret <- rep(NA, length(gev.params))

      if (enough.defined) {
        if (enough.unique) {
          # fit distribution and add them to the results array
          # TODO document why nmom=5

          lmr <- lmom::samlmu(pvals, nmom = 5)
          try(ret <- lmom::pelgev(lmr), silent=FALSE)

          # Optionally discard a fit if the scale is computed to be zero
          if (zero.scale.to.na & !is.na(ret[2]) & ret[2] == 0) {
            ret <- rep(NA, length(gev.params))
          }
        } else {
          # If there are not enough unique values, but there are enough
          # defined values, estimate the location with the median value
          # of those observed.

          ret <- c(stats::median(pvals, na.rm = TRUE), NA, NA)
        }
      }

      return(ret)
  }

  result_data <- array_apply(arr, gev_work)
  dimnames(result_data)[[3]] <- gev.params

  return (result_data)
}
