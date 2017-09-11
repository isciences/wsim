#' Write a RasterStack to a NetCDF file
#'
#' @param stk RasterStack containing named layers
#' @param filename output filename
#' @param attrs list of attributes to attach to the file,
#'        e.g., list(
#'                list(key='distribution', val='GEV'), # global attribute
#'                list(var='precipitation', key='units', val='mm)
#'              )
#' @param na.value NODATA value
#' @param prec data type for values.  Valid types:
#'       * short
#'       * integer
#'       * float
#'       * double
#'       * char
#'       * byte
#' @export
write_stack_to_cdf <- function(stk, filename, attrs=list(), na.value=-3.4e+38, prec="double") {
  minlat <- raster::extent(stk)[3]
  maxlat <- raster::extent(stk)[4]

  minlon <- raster::extent(stk)[1]
  maxlon <- raster::extent(stk)[2]

  data <- lapply(1:raster::nlayers(stk), function(i) {
    raster::as.matrix(stk[[i]])
  })
  names(data) <- names(stk)

  write_vars_to_cdf(vars=data, filename=filename, xmin=minlon, xmax=maxlon, ymin=minlat, ymax=maxlat, attrs=attrs, na.value=na.value, prec=prec)
}
