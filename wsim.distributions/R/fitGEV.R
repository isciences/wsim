#' Use L-moments to fit a GEV against observations in a RasterStack.
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
#' @param stk A RasterStack where each layer in the stack represents
#'        an observation of a single variable
#' @param nmin.unique Minimum number of unique values required to perform
#'        the fit
#' @param nmin.defined Minimum number of defined values required to perform
#'        the fit
#' @param zero.scale.to.na If TRUE, NA will be used instead of zero for a
#'        computed scale parameter.
#' @return A RasterStack representing the fitted (location, scale, shape)
#'         parameters of the GEV for each pixel
#'
fitGEV <- function(stk, nmin.unique=10, nmin.defined=10, zero.scale.to.na=TRUE) {
  # Record the dimensions of our inputs
  nrow.in <- nrow(stk)
  ncol.in <- ncol(stk)

  # Copy our inputs to an in-memory matrix, for speed
  data <- raster::as.array(stk)

  # Create an array to hold the parameter values of the GEV (3 per cell)
  dist.fit <- array(dim=c(nrow.in, ncol.in, 3))
  gev.params  <- c("location", "scale", "shape")

  for (i in 1:nrow.in) {
    for (j in 1:ncol.in) {
      pvals <- data[i, j, ]

      # Figure whether the pixel is missing more than nmin values.
      enough.defined <- sum(!is.na(pvals)) >= nmin.defined

      # Figure whether the pixel has enough unique values
      enough.unique <- length(na.omit(unique(pvals))) >= nmin.unique

      if (enough.defined) {
        if (enough.unique) {
          # fit distribution and add them to the results array
          # TODO document why nmom=5

          lmr <- lmom::samlmu(pvals, nmom = 5)
          try(dist.fit[i, j, ] <- lmom::pelgev(lmr), silent = FALSE)
        } else {
          # If there are not enough unique values, but there are enough
          # defined values, estimate the location with the median value
          # of those observed.

          dist.fit[i, j, ] <- c(median(pvals, na.rm = TRUE), NA, NA)
        }
      }

      if (zero.scale.to.na & !is.na(dist.fit[i, j, 2]) & dist.fit[i, j, 2] == 0) {
        dist.fit[pix, i, j, 2] <- NA
      }
    }
  }

  # Generate rasters of distribution parameters
  location <- raster::raster(as.matrix(dist.fit[,,1]), template=stk)
  scale    <- raster::raster(as.matrix(dist.fit[,,2]), template=stk)
  shape    <- raster::raster(as.matrix(dist.fit[,,3]), template=stk)

  fits <- raster::stack(location, scale, shape)
  names(fits) <- gev.params

  return (fits)
}
