#' Read multiple variables from a NetCDF file to a RasterBrick
#'
#' Global attributes will be attached to the RasterBrick as
#' metadata.  Variable attributes are currently ignored.
#'
#' @param fname name of NetCDF file
#' @return RasterBrick
#' @export
read_brick_from_cdf <- function(fname) {
  cdf <- read_vars_from_cdf(fname)

  fits <- raster::brick(lapply(names(cdf$data), function(var) {
    raster::raster(cdf$data[[var]],
                   xmn=cdf$extent[1],
                   xmx=cdf$extent[2],
                   ymn=cdf$extent[3],
                   ymx=cdf$extent[4])
  }))

  names(fits) <- names(cdf$data)
  raster::metadata(fits) <- cdf$attrs

  return(fits)
}
