#' Write distribution fit parameters to a NetCDF file
#'
#' @param RasterStack containing named fit parameters
#' @filename output filename
#' @attrs list of global attributes to attach to the file,
#'        e.g., list(distribution='GEV', month=as.integer(1))
#' @na.value NODATA value
#'
writeFit2Cdf <- function(fit, filename, attrs=list(), na.value=-3.4e+38) {
  nlat <- dim(fit)[1]
  nlon <- dim(fit)[2]

  minlat <- raster::extent(fit)[3]
  maxlat <- raster::extent(fit)[4]

  minlon <- raster::extent(fit)[1]
  maxlon <- raster::extent(fit)[2]

  dlat <- (maxlat - minlat) / nlat
  dlon <- (maxlon - minlon) / nlon

  # Compute our lat/lon grid (NetCDF uses cell centers, not corners)
  lats <- seq(minlat + (dlat/2), maxlat - (dlat/2), by=dlat)
  lons <- seq(minlon + (dlon/2), maxlon - (dlon/2), by=dlon)

  latdim <- ncdf4::ncdim_def("lat", "degrees_north", as.double(lats))
  londim <- ncdf4::ncdim_def("lon", "degrees_east", as.double(lons))

  ncvars <- lapply(names(fit), function(param) {
    ncdf4::ncvar_def(param, units="unknown", list(londim, latdim), na.value, prec="single")
  })

  names(ncvars) <- names(fit)

  # TODO which NetCDF version to use?
  ncout <- ncdf4::nc_create(filename, ncvars, force_v4 = FALSE)

  for (param in names(fit)) {
    ncdf4::ncvar_put(ncout, ncvars[[param]], values(raster::flip(fit[[param]], 'y')))
  }

  ncdf4::ncatt_put(ncout, "lon", "axis", "X")
  ncdf4::ncatt_put(ncout, "lat", "axis", "Y")

  # Write global attributes
  for (attr in names(attrs)) {
    ncdf4::ncatt_put(ncout, 0, attr, attrs[[attr]])
  }

  ncdf4::nc_close(ncout)
}
