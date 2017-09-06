#' Write a list of matrices to a netCDF file.
#'
#' The names of the list elements will be used to name the
#' variable associated with each matrix.  Consistent with the
#' raster package, it is assumed that matrices are stored as
#' (lat, lon), with lon increasing and lat decreasing.
#'
#' @param List of matrices containing values to write
#' @param xmin lowest longitude value (left side of cell)
#' @param xmax highest longitude value (right side of cell)
#' @param ymin lowest latitude value (bottom of cell)
#' @param ymax highest latitude value (topof cell)
#' @param attrs List of attributes to associate with the file,
#'              or with each variable.  Each attribute is
#'              described by a list, with the following
#'              properties:
#'              \describe{
#'              \item{var}{Variable with which the attribute
#'              is associated, or NULL for a global attribute}
#'              \item{key}{Name of the attribute}
#'              \item{val}{Value of the attribute}
#'              }
#'
#'@export
write_vars_to_cdf <- function(vars, xmin, xmax, ymin, ymax, filename, attrs=list(), na.value=-3.4e+38, prec="double") {
  standard_attrs <- list(
    list(key="date_created", val=strftime(Sys.time(), '%Y-%m-%dT%H:%M%S%z')),
    list(var="lon", key="axis", val="X"),
    list(var="lon", key="standard_name", val="longitude"),
    list(var="lat", key="axis", val="Y"),
    list(var="lat", key="standard_name", val="latitude")
  )

  nlat <- dim(vars[[1]])[1]
  nlon <- dim(vars[[1]])[2]

  minlat <- ymin
  maxlat <- ymax

  minlon <- xmin
  maxlon <- xmax

  dlat <- (maxlat - minlat) / nlat
  dlon <- (maxlon - minlon) / nlon

  # Compute our lat/lon grid (NetCDF uses cell centers, not corners)
  lats <- seq(maxlat - (dlat/2), minlat + (dlat/2), by=-dlat)
  lons <- seq(minlon + (dlon/2), maxlon - (dlon/2), by=dlon)

  latdim <- ncdf4::ncdim_def("lat", units="degrees_north", vals=as.double(lats), longname="Latitude", create_dimvar=TRUE)
  londim <- ncdf4::ncdim_def("lon", units="degrees_east", vals=as.double(lons), longname="Longitude", create_dimvar=TRUE)

  # Create all variables, putting in blank strings for the units.  We will
  # overwrite this with the actual units, if they have been passed in
  # as attributes.
  ncvars <- lapply(names(vars), function(param) {
    ncdf4::ncvar_def(name=param,
                     units="",
                     dim=list(londim, latdim),
                     missval=na.value,
                     prec=prec,
                     compression=1)
  })

  names(ncvars) <- names(vars)

  ncout <- ncdf4::nc_create(filename, ncvars)

  # Write data to vars
  for (param in names(vars)) {
    ncdf4::ncvar_put(ncout, ncvars[[param]], t(vars[[param]]))
  }

  # Write attributes
  for (attr in c(standard_attrs, attrs)) {
    ncdf4::ncatt_put(ncout,
                     ifelse(is.null(attr$var), 0, attr$var),
                     attr$key,
                     attr$val)
  }

  ncdf4::nc_close(ncout)
}
