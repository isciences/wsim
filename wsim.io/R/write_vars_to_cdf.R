#' Write a list of matrices to a netCDF file.
#'
#' The names of the list elements will be used to name the
#' variable associated with each matrix.  Consistent with the
#' raster package, it is assumed that matrices are stored as
#' (lat, lon), with lon increasing and lat decreasing.
#'
#' @param vars List of matrices containing values to write
#' @param extent vector of (xmin, xmax, ymin, ymax)
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
write_vars_to_cdf <- function(vars, filename, extent=NULL, xmin=NULL, xmax=NULL, ymin=NULL, ymax=NULL, attrs=list(), prec="double") {
  standard_attrs <- list(
    list(key="Conventions", val="CF-1.6"),
    list(key="date_created", val=strftime(Sys.time(), '%Y-%m-%dT%H:%M%S%z')),
    list(var="lon", key="axis", val="X"),
    list(var="lon", key="standard_name", val="longitude"),
    list(var="lat", key="axis", val="Y"),
    list(var="lat", key="standard_name", val="latitude")
  )

  default_nodata <- list(
    byte= -127,
    integer= -9999,
    single=-3.4028234663852886e+38,
    float= -3.4028234663852886e+38,
    double= -3.4028234663852886e+38
  )

  var_prec <- function(var) {
    if (is.character(prec)) {
      return(prec)
    }

    if (is.list(prec)) {
      return(prec[[var]])
    }
  }

  var_fill <- function(var) {
    fill <- default_nodata[[var_prec(var)]]
    stopifnot(!is.null(fill))
    return(fill)
  }

  if (is.null(extent)) {
    minlat <- ymin
    maxlat <- ymax

    minlon <- xmin
    maxlon <- xmax
  } else {
    minlat <- extent[3]
    maxlat <- extent[4]

    minlon <- extent[1]
    maxlon <- extent[2]
  }

  nlat <- dim(vars[[1]])[1]
  nlon <- dim(vars[[1]])[2]

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
                     missval=var_fill(param),
                     prec=var_prec(param),
                     compression=1)
  })

  names(ncvars) <- names(vars)

  # Add a CRS var
  ncvars$crs <- ncdf4::ncvar_def(name="crs", units="", dim=list(), missval=NULL, prec="integer")

  # Does the file already exist?
  if (file.exists(filename)) {
    ncout <- ncdf4::nc_open(filename, write=TRUE)

    # Verify that our dimensions match up before writing
    existing_lats <- ncdf4::ncvar_get(ncout, "lat")
    existing_lons <- ncdf4::ncvar_get(ncout, "lon")

    stopifnot(all(lats == existing_lats))
    stopifnot(all(lons == existing_lons))

    # Add any missing variable definitions
    for (var in ncvars) {
      if (!(var$name %in% names(ncout$var))) {
        ncout <- ncdf4::ncvar_add(ncout, var)
      }
    }
  } else {
    ncout <- ncdf4::nc_create(filename, ncvars)
  }

  # Write data to vars
  for (param in names(vars)) {
    ncdf4::ncvar_put(ncout, ncvars[[param]], t(vars[[param]]))
  }

  # Write attributes
  for (attr in c(standard_attrs, attrs)) {
    varid <- ifelse(is.null(attr$var), 0, attr$var)

    existing <- ncdf4::ncatt_get(ncout, varid, attname=attr$key)

    # Don't try writing an attribute if our value is equivalent to
    # what's already there.
    # This is to avoid the ncdf4 library thinking we're trying to
    # redefine _FillValue, even if we're (re)-setting it to its
    # current value.
    if (!existing$hasatt || existing$value != attr$val) {
      ncdf4::ncatt_put(ncout,
                       varid,
                       attr$key,
                       attr$val)
    }
  }

  ncdf4::ncatt_put(ncout, "crs", "grid_mapping_name", "latitude_longitude")
  ncdf4::ncatt_put(ncout, "crs", "longitude_of_prime_meridian", 0.0)
  ncdf4::ncatt_put(ncout, "crs", "semi_major_axis", 6378137.0)
  ncdf4::ncatt_put(ncout, "crs", "inverse_flattening", 298.257223563)
  ncdf4::ncatt_put(ncout, "crs", "spatial_ref", "GEOGCS[\"GCS_WGS_1984\",DATUM[\"WGS_1984\",SPHEROID[\"WGS_84\",6378137.0,298.257223563]],PRIMEM[\"Greenwich\",0.0],UNIT[\"Degree\",0.017453292519943295]]")

  for (var in names(vars)) {
    ncdf4::ncatt_put(ncout, var, "grid_mapping", "crs")
  }

  ncdf4::nc_close(ncout)
}
