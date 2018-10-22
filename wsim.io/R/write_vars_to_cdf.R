# Copyright (c) 2018 ISciences, LLC.
# All rights reserved.
#
# WSIM is licensed under the Apache License, Version 2.0 (the "License").
# You may not use this file except in compliance with the License. You may
# obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0.
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#' Default NODATA values for various data types
default_netcdf_nodata <- list(
  byte= -127,
  integer= -9999,
  single=-3.4028234663852886e+38,
  float= -3.4028234663852886e+38,
  double= -3.4028234663852886e+38
)

#' Write a list of matrices to a netCDF file.
#'
#' The names of the list elements will be used to name the
#' variable associated with each matrix.  Consistent with the
#' raster package, it is assumed that matrices are stored as
#' (lat, lon), with lon increasing and lat decreasing.
#'
#' @param vars List of matrices containing values to write,
#'             or a 3D with dimension names on the third
#'             dimension.
#' @param filename Name of output file
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
#' @param prec   The numerical precision with which \code{vars}
#'               should be written. Can be either a character vector,
#'               in which case the same precision will be used for
#'               all variables, or a list whose names correspond to
#'               the names of \code{vars}, specifying a precision for
#'               each variable. Acceptable precision descriptions
#'               include:
#'               \itemize{
#'               \item byte
#'               \item integer
#'               \item single
#'               \item float
#'               \item double
#'               }
#' @param append Determines if we should add variables to an existing
#'               file, if present.
#'
#'@export
write_vars_to_cdf <- function(vars, filename, extent=NULL, ids=NULL, xmin=NULL, xmax=NULL, ymin=NULL, ymax=NULL, attrs=list(), prec="double", append=FALSE) {
  datestring  <- strftime(Sys.time(), '%Y-%m-%dT%H:%M%S%z')
  history_entry <- paste0(datestring, ': ', get_command(), '\n')

  is_spatial <- is.null(ids)

  standard_attrs <- list(
    list(key="Conventions", val="CF-1.6"),
    list(key="wsim_version", val=wsim_version_string())
  )

  if (is.array(vars)) {
    vars <- cube_to_matrices(vars)
  }

  # Return the data precision for variable named var
  var_prec <- function(var) {
    if (is.character(prec)) {
      return(prec)
    }

    if (is.list(prec)) {
      return(prec[[var]])
    }
  }

  # Return a fill value to use for the variable named var
  var_fill <- function(var) {
    fill <- default_netcdf_nodata[[var_prec(var)]]
    stopifnot(!is.null(fill))
    return(fill)
  }

  if (is_spatial) {
    extent <- validate_extent(extent, xmin, xmax, ymin, ymax)

    lats <- lat_seq(extent, dim(vars[[1]]))
    lons <- lon_seq(extent, dim(vars[[1]]))

    dims <- list(
      ncdf4::ncdim_def("lon", units="degrees_east", vals=lons, longname="Longitude", create_dimvar=TRUE),
      ncdf4::ncdim_def("lat", units="degrees_north", vals=lats, longname="Latitude", create_dimvar=TRUE)
    )

    standard_attrs <- c(standard_attrs, list(
      list(var="lon", key="axis", val="X"),
      list(var="lon", key="standard_name", val="longitude"),
      list(var="lat", key="axis", val="Y"),
      list(var="lat", key="standard_name", val="latitude")
    ))
  } else {
    dims <- list(
      ncdf4::ncdim_def("id", units="", vals=coerce_to_integer(ids), create_dimvar=TRUE)
    )
  }

  # Create all variables, putting in blank strings for the units.  We will
  # overwrite this with the actual units, if they have been passed in
  # as attributes.
  ncvars <- lapply(names(vars), function(param) {
    ncdf4::ncvar_def(name=param,
                     units="",
                     dim=dims,
                     missval=var_fill(param),
                     prec=var_prec(param),
                     compression=1)
  })

  names(ncvars) <- names(vars)

  if (is_spatial) {
    # Add a CRS var
    ncvars$crs <- ncdf4::ncvar_def(name="crs", units="", dim=list(), missval=NULL, prec="integer")
  }

  # Does the file already exist?
  if (append && file.exists(filename)) {
    ncout <- ncdf4::nc_open(filename, write=TRUE)

    # Verify that our dimensions match up before writing
    if (is_spatial) {
      check_coordinate_variables(ncout, lat=lats, lon=lons)
    } else {
      check_coordinate_variables(ncout, id=ids)
    }

    # Add any missing variable definitions
    for (var in ncvars) {
      if (!(var$name %in% names(ncout$var))) {
        ncout <- ncdf4::ncvar_add(ncout, var)
      }
    }

    existing_history <- ncdf4::ncatt_get(ncout, 0, "history")
    if (existing_history$hasatt) {
      history_entry <- paste0(existing_history$value, history_entry)
    }

    standard_attrs <- c(standard_attrs, list(
      list(key="history", val=history_entry)
    ))
  } else {
    ncout <- ncdf4::nc_create(filename, ncvars)

    standard_attrs <- c(standard_attrs, list(
      list(key="date_created", val=datestring),
      list(key="history", val=history_entry)
    ))
  }

  # Write data to vars
  for (param in names(vars)) {
    ncdf4::ncvar_put(ncout, ncvars[[param]], t(vars[[param]]))
  }

  # Write attributes
  for (attr in c(standard_attrs, attrs)) {
    if (!is.null(attr$var) && attr$var == '*') {
      # Global attribute. Apply the attribute to all variables modified
      # in this function call.
      for (var in names(vars)) {
        update_attribute(ncout, var, attr$key, attr$val, attr$prec)
      }
    } else {
      update_attribute(ncout, attr$var, attr$key, attr$val, attr$prec)
    }
  }

  if (is_spatial) {
    write_wgs84_crs_attributes(ncout, names(vars))
  }

  ncdf4::nc_close(ncout)
}

#' Validate coordinate variables
#'
#' @param ncout a netCDF file opened for writing
#' @param ... values of any named dimension variables
check_coordinate_variables <- function(ncout, ...) {
  vars <- list(...)

  for (v in names(vars)) {
    if (!is.null(ncout$dim[[v]])) {
      existing <- ncdf4::ncvar_get(ncout, v)
      current <- vars[[v]]

      if (length(current) != length(existing)) {
        stop("Cannot write ", v, " of dimension ", length(current), " to existing file with dimension ", length(existing))
      }

      if (any(current != existing)) {
        stop("Values of dimension ", v, " do not match existing values.")
      }
    }
  }
}

#' Update an attribute in ncout
#'
#' @param var the name of the variable to which the attribute
#'            is associated (or \code{NULL} for a global attribute)
#' @param key the name of the attribute
#' @param val the value of the attribute
#' @param prec the precision of the attribute (or \code{NULL} to
#'             use the same precision as \code{var})
update_attribute <- function(ncout, var, key, val, prec) {
    varid <- ifelse(is.null(var), 0, var)

    existing <- ncdf4::ncatt_get(ncout, varid, attname=key)

    # Don't try writing an attribute if our value is equivalent to
    # what's already there.
    # This is to avoid the ncdf4 library thinking we're trying to
    # redefine _FillValue, even if we're (re)-setting it to its
    # current value.
    if (!existing$hasatt || existing$value != val) {
      ncdf4::ncatt_put(ncout,
                       varid,
                       key,
                       val,
                       prec=ifelse(is.null(prec), NA, prec))
    }
}

#' Write CRS attributes for WGS84
#'
#' @param ncout    netCDF open for writing
#' @param varnames list of variable names to which CRS should be associated
write_wgs84_crs_attributes <- function(ncout, var_names) {
  ncdf4::ncatt_put(ncout, "crs", "grid_mapping_name", "latitude_longitude")
  ncdf4::ncatt_put(ncout, "crs", "longitude_of_prime_meridian", 0.0)
  ncdf4::ncatt_put(ncout, "crs", "semi_major_axis", 6378137.0)
  ncdf4::ncatt_put(ncout, "crs", "inverse_flattening", 298.257223563)
  ncdf4::ncatt_put(ncout, "crs", "spatial_ref", "GEOGCS[\"GCS_WGS_1984\",DATUM[\"WGS_1984\",SPHEROID[\"WGS_84\",6378137.0,298.257223563]],PRIMEM[\"Greenwich\",0.0],UNIT[\"Degree\",0.017453292519943295]]")

  for (var in var_names) {
    ncdf4::ncatt_put(ncout, var, "grid_mapping", "crs")
  }
}

validate_extent <- function(extent, xmin, xmax, ymin, ymax) {
  # Must provide extent in one form or another
  if (is.null(extent) && any(is.null(c(xmin, xmax, ymin, ymax)))) {
      stop("Must provide either extent or xmin, xmax, ymin, ymax")
  }

  # Can't provide extent in both forms
  if (!is.null(extent) && !all(is.null(c(xmin, xmax, ymin, ymax)))) {
      stop("Both extent and xmin, xmax, ymin, ymax arguments provided.")
  }

  if (is.null(extent)) {
    extent <- c(xmin, xmax, ymin, ymax)
  }

  if (length(extent) != 4) {
    stop("Extent should be provided as (xmin, xmax, ymin, ymax)")
  }

  if (extent[2] < extent[1]) {
    stop("Provided extent has xmax < xmin")
  }

  if (extent[4] < extent[3]) {
    stop("Provided extent has ymax < ymin")
  }

  return(extent)
}
