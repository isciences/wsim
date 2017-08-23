#' applyDistToStack
#'
#' Applies a statistical distribution to a RasterStack of observations,
#' given a RasterStack containing distribution fit parameters for
#' each pixel.
#'
#' Exactly what "applying a statistical distribution" means is the
#' responsibility of the user-supplied "fn" parameter.  Examples include
#' computing standardized anomalies or return periods at each pixel, or
#' bias-correcting observed data using quantile matching.
#'
#' If the distribution parameters are undefined at a given pixel,
#' a specified default value can be used.
#'
#' @param dist_params A RasterStack/Brick whose component rasters
#'        contain the fit parameters of the statistical
#'        distribution
#' @param obs A RasterStack/Brick whose component rasters contain observations
#'            against which the distribution should be applied.
#' @param fn  A function to apply the distribution to the observations,
#'            when the distribution is defined.  Should have signature
#'            function(value, dist_params)
#' @param when.dist.undefined A value to use when the distribution is
#'                            undefined
#' @return A Raster(Brick) of the supplied function applied to the observations
#' @export
applyDistToStack <- function(dist_params, obs, fn, when.dist.undefined=NA) {
  nlayers <- raster::nlayers(obs)
  nrow <- nrow(obs)
  ncol <- ncol(obs)

  # Convert dist_params to a 3D array locally for performance.
  # Makes an enormous speed difference.
  dist_params <- raster::as.array(dist_params)
  obs_array <- raster::as.array(obs)
  results <- array(dim=dim(obs))

  for (ix in 1:nrow(obs)) {
    for (iy in 1:ncol(obs)) {
      # get the fit parameters for this pixel
      gev.vals <- dist_params[ix,iy,]

      # only work where we have fits
      if (all(!is.na(gev.vals))) {
        results[ix, iy, ] <- fn(obs_array[ix, iy, ], gev.vals)
      } else {
        results[ix, iy, ] <- when.dist.undefined
      }
    }
  }

  if (nlayers == 1) {
    return(raster::raster(as.matrix(results[,,1]), template=obs))
  } else {
    return(raster::stack(lapply(1:nlayers, function(i) raster::raster(results[,,i], template=obs))))
  }
}
