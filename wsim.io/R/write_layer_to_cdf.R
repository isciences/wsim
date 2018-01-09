#' Write a RasterLayer to a NetCDF file
#'
#' @param lyr RasterLayer to write
#' @param filename output filename
#' @param varname variable name to use in NetCDF file
#' @param attrs list of attributes to attach to the file,
#'        e.g., list(
#'                list(key='distribution', val='GEV'), # global attribute
#'                list(var='precipitation', key='units', val='mm)
#'              )
#' @param prec data type for values.  Valid types:
#'       * short
#'       * integer
#'       * float
#'       * double
#'       * char
#'       * byte
#' @export
write_layer_to_cdf <- function(lyr, filename, varname, attrs=list(), prec="double") {
  stk <- raster::stack(lyr)
  names(stk) <- c(varname)
  write_stack_to_cdf(stk, filename, attrs, prec)
}
