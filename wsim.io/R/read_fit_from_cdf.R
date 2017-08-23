#' Read distribution fit parameters from a NetCDF file to a RasterBrick
#'
#' It is assumed that the file contains only fit parameters, and
#' that an identifier for the statistical distribution is stored as
#' a global "distribution" attribute.  This distribution identified
#' will be recorded in the metadata of the returned RasterBrick
#'
#' @param fname name of NetCDF file containing fit parameters
#' @return RasterBrick of fit parameters
#' @export
read_fit_from_cdf <- function(fname) {
  cdf <- ncdf4::nc_open(fname)

  distribution <- ncdf4::ncatt_get(cdf, 0, 'distribution')$value
  vars <- names(cdf$var)
  ncdf4::nc_close(cdf)

  fits <- raster::brick(lapply(names(cdf$var), function(var) {
    raster::raster(fname, varname=var)
  }))

  raster::metadata(fits) <- list(distribution=distribution)

  return(fits)
}
