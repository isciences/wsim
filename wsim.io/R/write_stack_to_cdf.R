#' Write a RasterStack to a NetCDF file
#'
#' @param stk RasterStack containing named layers
#' @param filename output filename
#' @param attrs list of global attributes to attach to the file,
#'        e.g., list(distribution='GEV', month=as.integer(1))
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
  nlat <- dim(stk)[1]
  nlon <- dim(stk)[2]

  minlat <- raster::extent(stk)[3]
  maxlat <- raster::extent(stk)[4]

  minlon <- raster::extent(stk)[1]
  maxlon <- raster::extent(stk)[2]

  dlat <- (maxlat - minlat) / nlat
  dlon <- (maxlon - minlon) / nlon

  # Compute our lat/lon grid (NetCDF uses cell centers, not corners)
  lats <- seq(minlat + (dlat/2), maxlat - (dlat/2), by=dlat)
  lons <- seq(minlon + (dlon/2), maxlon - (dlon/2), by=dlon)

  latdim <- ncdf4::ncdim_def("lat", "degrees_north", as.double(lats))
  londim <- ncdf4::ncdim_def("lon", "degrees_east", as.double(lons))

  ncvars <- lapply(names(stk), function(param) {
    ncdf4::ncvar_def(param, units="unknown", list(londim, latdim), na.value, prec=prec)
  })

  names(ncvars) <- names(stk)

  # TODO which NetCDF version to use?
  ncout <- ncdf4::nc_create(filename, ncvars, force_v4 = FALSE)

  for (param in names(stk)) {
    ncdf4::ncvar_put(ncout, ncvars[[param]], raster::values(raster::flip(stk[[param]], 'y')))
  }

  ncdf4::ncatt_put(ncout, "lon", "axis", "X")
  ncdf4::ncatt_put(ncout, "lat", "axis", "Y")

  # Write global attributes
  for (attr in names(attrs)) {
    ncdf4::ncatt_put(ncout, 0, attr, attrs[[attr]])
  }

  ncdf4::nc_close(ncout)
}
