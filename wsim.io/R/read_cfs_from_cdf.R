#' Read a CFSv2 forecast netCDF
#'
#' Returned values will be in Celsius (temp) or
#' mm (precip)
#'
#' @param filename filename to read
#' @return matrix of forecast data
#' @export
read_cfs_from_cdf <- function(filename) {
  forecast <- read_vars_from_cdf(filename)

  if (!is.null(forecast$data$tmp2m)) {
    # Convert Kelvin to Celsius
    forecast$data$tmp2m <- forecast$data$tmp2m - 273.15
  }

  if (!is.null(forecast$data$prate)) {
    # Convert to mm month-1 from kg m-2 s-1.
    # Use equivalency of 1 kg/m-2 s = 1 mm/s and work
    # through the time units to arrive at this
    forecast$data$prate <- forecast$data$prate * 2628000
  }

  return(forecast)
}
