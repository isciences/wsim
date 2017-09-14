#' Read a CFSv2 forecast NetCDF
#'
#' Returned values will be in Celsius (temp) or
#' kg m-2 s-1 (precip)
#'
#' @param filename filename to read
#' @return matrix of forecast data
#' @export
readCFSv2 <- function(filename) {
  # TODO remove use of raster package
  forecast <- raster::raster(filename)
  zvar <- forecast@data@zvar

  raster::extent(forecast) <- c(0, 360, -90, 90)
  forecast <- raster::rotate(forecast)
  forecast <- raster::flip(forecast, 'y')

  if (zvar == 'tmp2m') {
    # Convert Kelvin to Celsius
    forecast <- forecast - 273.15
  } else if (zvar == 'prate') {
    # Convert to mm month-1 from kg m-2 s-1.
    # Use equivalency of 1 kg/m-2 s = 1 mm/s and work
    # through the time units to arrive at this
    forecast <- forecast * 2628000
  }

  return(raster::as.matrix(forecast))
}
