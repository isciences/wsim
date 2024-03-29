# Copyright (c) 2018-2022 ISciences, LLC.
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
  char= NULL,
  short=-32768,
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
#' @param ids  vector of integer or character IDs
#' @param xmin lowest longitude value (left side of cell)
#' @param xmax highest longitude value (right side of cell)
#' @param ymin lowest latitude value (bottom of cell)
#' @param ymax highest latitude value (top of cell)
#' @param extra_dims Optional list of extra dimensions (excluding
#'                   'id' or spatial dimensions). Specified as a list
#'                   with dimension names as keys and a vector of
#'                   acceptable values as values, e.g.
#'                   \code{extra_dims=list(crop=c('maize', 'rice'), season=c('spring', 'fall'))}
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
#'               each variable. If \code{vars} is \code{NULL}, or a
#'               variable is not specified in a list, a default precision
#'               will be selected depending on the values.
#'               Acceptable precision descriptions include:
#'               \itemize{
#'               \item byte (8-bit signed integer)
#'               \item short (16-bit signed integer)
#'               \item integer (32-bit signed integer)
#'               \item single (32-bit floating point)
#'               \item float (32-bit floating point)
#'               \item double (64-bit floating point)
#'               }
#' @param append       Determines if we should add variables to an existing
#'                     file, if present.
#' @param write_slice  Optional list used to write a two-dimensional array
#'                     (lat, lon) across constant values of other dimensions.
#'                     List keys are used to indicate dimension names and values
#'                     are used to indicate the constant value for that dimension.
#' @param put_data     Flag indicating whether to write data contained in
#'                     \code{vars}. If \code{FALSE}, only dimensions and
#'                     coordinate varibles will be written.
#' @param quick_append Flag indicating whether to validate that data
#'                     written in an append operation conforms to the
#'                     original dimensions of the file. If \code{TRUE},
#'                     these checks will not be performed, increasing
#'                     write performance.
#'
#'@export
write_vars_to_cdf <- function(vars,
                              filename,
                              extent=NULL,
                              ids=NULL,
                              xmin=NULL,
                              xmax=NULL,
                              ymin=NULL,
                              ymax=NULL,
                              extra_dims=NULL,
                              write_slice=NULL,
                              attrs=list(),
                              prec=NULL,
                              append=FALSE,
                              put_data=TRUE,
                              quick_append=FALSE) {
  # TODO allow implicit id definition with 'id' col in vars
  is_spatial <- is.null(ids)
  character_ids <- !is_spatial && mode(ids) == 'character'

  vars <- standardize_vars(vars)
  extent <- standardize_extent(extent, xmin, xmax, ymin, ymax)
  ids <- standardize_ids(ids)

  if (is.null(extent) && is.null(ids)) {
    stop("Must provide either extent or ids")
  }

  # check size of arguments
  # needed to prevent silent recycling?
  # TODO move into fn
  if (is_spatial) {
    # TODO implement
  } else {
    if (is.null(extra_dims) || !is.null(write_slice)) {
      verify_var_size(vars, length(ids))
    } else {
      verify_var_size(vars, length(ids)*prod(sapply(extra_dims, length)))
    }
  }

  if (append && file.exists(filename)) {
    ncout <- ncdf4::nc_open(filename, write=TRUE)

    # Verify that our dimensions match up before writing
    if (!quick_append) {
      use_compression <- (ncout$format != 'NC_FORMAT_CLASSIC')

      unlimited_dims <- Filter(function(dimname) ncout$dim[[dimname]]$unlim,
                               names(ncout$dim))

      dims <- make_netcdf_dims(vars, extent, ids, extra_dims, unlimited_dims)
      ncvars <- create_vars(vars, dims, ids, prec, extra_dims, use_compression)

      # Check that the dimensions of the data to write match up
      # with the data already in the file.
      for (dim in names(dims)) {
        if (dim == 'id') {
          check_coordinate_variable(ncout, 'id', ids)
        } else if (dim %in% names(extra_dims)) {
          check_coordinate_variable(ncout, dim, extra_dims[[dim]])
        } else {
          # this only works for numeric dim values, which is why we
          # handle extra_dims and id separately
          check_coordinate_variable(ncout, dim, dims[[dim]]$vals)
        }
      }

      # Make sure the slice we're writing to actually exists
      check_values_exist_in_dimension(ncout, write_slice)

      # Add any missing variable definitions
      for (var in ncvars) {
        if (!(var$name %in% names(ncout$var) || var$name %in% names(ncout$dim))) {
          ncout <- ncdf4::ncvar_add(ncout, var)
        }
      }
    }
  } else {
    # Creating a new file
    dims <- make_netcdf_dims(vars, extent, ids, extra_dims)
    ncvars <- create_vars(vars, dims, ids, prec, extra_dims, compress=TRUE)

    ncout <- ncdf4::nc_create(filename, ncvars)

    if (character_ids) {
      ncdf4::ncvar_put(ncout, ncvars$id, ids)
    }

    for (dimname in names(extra_dims)) {
      ncdf4::ncvar_put(ncout, dims[[dimname]], extra_dims[[dimname]])
    }
  }

  # Write data to vars
  if (!is_spatial) {
    # Get a data frame representing the Cartesian product of all dimensions
    # so that we can properly fill in missing values with NA
    dimension_df <- do.call(combos, c(list(id=ids), extra_dims))
  }

  if (put_data) {
    for (param in names(vars)) {
      # Don't write dimension vals
      if (!is.null(dims[[param]])) {
        next
      }

      # Figure out what dimensions are used for this variable
      dimnames <- sapply(ncout$var[[param]]$dim, function(d) d$name)

      if (is_spatial) {
        dat <- flip_first_two_dims(vars[[param]])
      } else {
        if (is.null(extra_dims)) {
          dat <- vars[[param]]
        } else {
          # Join our data to dimension_df to fill in missing values
          dat <- merge(dimension_df, vars, by=names(dimension_df), all.x=TRUE)

          # Sort the data frame according to the order of dimension values used in the netCDF file
          # Then, drop off the dimension columns
          dat <- dat[do.call(order, lapply(rev(dimnames), function(d) match(dat[[d]], ncdf4::ncvar_get(ncout, d)))), param]
        }
      }

      verbose <- FALSE
      ncdf4::ncvar_put(nc = ncout,
                       varid = param,
                       vals = dat,
                       start = find_offset(ncout, dimnames, write_slice),
                       count = find_count(dimnames, write_slice),
                       verbose = verbose)
    }
  }

  # Write attributes
  if (!append || !quick_append) {
    if (append && ncdf4::ncatt_get(ncout, 0, "history")$hasatt) {
      existing_history <- ncdf4::ncatt_get(ncout, 0, "history")$value
    } else {
      existing_history <- NULL
    }

    standard_attrs <- standard_netcdf_attrs(is_new = !append,
                                            is_spatial = is_spatial,
                                            existing_history = existing_history)

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
  }

  ncdf4::nc_close(ncout)
}

#' Validate coordinate variables
#'
#' @param ncout a netCDF file opened for writing
#' @param varname the name of a coordinate variable
#' @param values expected values of the coodinate variable
check_coordinate_variable <- function(ncout, varname, values) {
  if (!is.null(ncout$dim[[varname]])) {
    existing <- ncdf4::ncvar_get(ncout, varname)
    current <- values

    if (length(current) != length(existing)) {
      stop("Cannot write ", varname, " of dimension ", length(current), " to existing file with dimension ", length(existing))
    }

    if (any(current != existing)) {
      stop("Values of dimension ", varname, " do not match existing values.")
    }
  }
}

#' Validate extra dimensions
#'
#' @param ncout a netCDF file opened for writing
#' @param vars  list containing values of any named dimension variables
check_values_exist_in_dimension <- function(ncout, vars) {
  for (v in names(vars)) {
    if (!(vars[[v]] %in% ncout$dim[[v]]$vals)) {
      stop("Invalid value \"", vars[[v]], "\" for dimension \"", v, "\"")
    }
  }
}

#' Update an attribute in ncout
#'
#' @param ncout file handle for netCDF in which attributes should be
#'              updated
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
#' @param ncout     netCDF open for writing
#' @param var_names list of variable names to which CRS should be associated
write_wgs84_crs_attributes <- function(ncout, var_names) {
  ncdf4::ncatt_put(ncout, "crs", "grid_mapping_name", "latitude_longitude")
  ncdf4::ncatt_put(ncout, "crs", "longitude_of_prime_meridian", 0.0)
  ncdf4::ncatt_put(ncout, "crs", "semi_major_axis", 6378137.0)
  ncdf4::ncatt_put(ncout, "crs", "inverse_flattening", 298.257223563)
  ncdf4::ncatt_put(ncout, "crs", "spatial_ref", 'GEOGCS["WGS 84",DATUM["WGS_1984",SPHEROID["WGS 84",6378137,298.257223563,AUTHORITY["EPSG","7030"]],AUTHORITY["EPSG","6326"]],PRIMEM["Greenwich",0,AUTHORITY["EPSG","8901"]],UNIT["degree",0.0174532925199433,AUTHORITY["EPSG","9122"]],AXIS["Latitude",NORTH],AXIS["Longitude",EAST],AUTHORITY["EPSG","4326"]]')

  for (var in var_names) {
    ncdf4::ncatt_put(ncout, var, "grid_mapping", "crs")
  }
}

standardize_extent <- function(extent, xmin, xmax, ymin, ymax) {
  if (is.null(extent)) {
    extent <- c(xmin, xmax, ymin, ymax)

    if (all(is.null(extent))) {
      return(NULL)
    }

    if (any(is.null(c(xmin, xmax, ymin, ymax)))) {
        stop("Must provide either extent or xmin, xmax, ymin, ymax")
    }
  } else {
    if (!all(is.null(c(xmin, xmax, ymin, ymax)))) {
      stop("Both extent and xmin, xmax, ymin, ymax arguments provided.")
    }
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

#' Create a character-type dimension variable
#'
#' @param dim     \code{ncdim} handle
#' @param varname name of dimension/variable
#' @param vals    values of dimension
create_char_dimension_variable <- function(dim, varname, vals) {
  nchar_dim <- ncdf4::ncdim_def(sprintf("%s_nchar", varname), units="", vals=1:max(nchar(vals)), create_dimvar=FALSE)
  ncdf4::ncvar_def(name=dim$name, units="", dim=list(nchar_dim, dim), missval=NULL, prec='char')
}

#' Return the data precision for variable named var

#' @param var  name of the variable
#' @param vals list containing data for vars
#' @param prec precision argument as described in write_vars_to_cdf
#' @return text representation of precision for variable
var_prec <- function(var, vals, prec) {
  if (is.character(prec)) {
    return(prec)
  }

  # return var-specific floating-point type, as specified by arg
  if (is.list(prec) && !is.null(prec[[var]])) {
    return(prec[[var]])
  }

  # Guess precision
  if (mode(vals) == 'logical' || all(vals %in% c(0,1)))
    return('byte') # ncdf4 library does not support bool type

  if (mode(vals) == 'character')
    return('char') # ncdf4 library does not support string type

  # return default floating-point type, as specified by arg
  if (can_coerce_to_integer(vals)) {
    return('integer')
  }

  return('double')
}

#' Return a fill value to use for the variable named var
#'
#' @inheritParams var_prec
var_fill <- function(var, vals, prec) {
  stopifnot(var_prec(var, vals, prec) %in% names(default_netcdf_nodata))

  default_netcdf_nodata[[var_prec(var, vals, prec)]]
}

verify_var_size <- function(vars, sz) {
  for(varname in names(vars)) {
    if (varname != 'id') {
      if (length(vars[[varname]]) != sz) {
        stop(sprintf("Variable %s has %d values but we expected %d for the supplied ids/extra dimensions.",
                     varname, length(vars[[varname]]), sz))
      }
    }
  }
}

standardize_vars <- function(vars) {
  # convert 3D to list of matrices
  if (is.array(vars)) {
    vars <- cube_to_matrices(vars)
  }

  if (is.null(names(vars)) || length(vars) != length(names(vars))) {
    stop("vars must be an array with dimnames, or a named list of variables.")
  }

  # convert factors to text
  for (varname in names(vars)) {
    if(is.factor(vars[[varname]])) {
      vars[[varname]] <- as.character(vars[[varname]])
    }
  }

  return(vars)
}

standardize_ids <- function(ids) {
  if (is.null(ids)) {
    return(NULL)
  }

  if (any(is.na(ids))) {
    stop('All IDs must be defined.')
  }

  if (mode(ids) == 'character') {
    return(ids)
  } else {
    return(coerce_to_integer(ids))
  }
}

#' Create a ncvar4 object
#'
#' @param dims list of \code{ncdim4} objects
#' @param varname name of the variable
#' @param vals values for the variable
#' @param prec argument passed to write_vars_to_cdf
#' @param compress should compression be enabled for the new variable?
#' @return a \code{ncvar4} object for the variable
create_var <- function(dims, varname, vals, prec, compress) {
  is_spatial <- is.null(dims$id)

  if (mode(vals) == "character") {
    if (is_spatial) {
      stop("Character data only supported for non-spatial datasets.")
    }

    nchar_dim <- ncdf4::ncdim_def(paste0(varname, "_nchar"),
                                  units="",
                                  vals=1:max(nchar(vals), na.rm=TRUE),
                                  create_dimvar=FALSE)
    vardims <- list(nchar_dim, dims$id)
  } else {
    vardims <- dims
  }

  # Chunk into scanlines (applies to compressed outputs only)
  if (compress) {
    chunksizes <- sapply(vardims, `[[`, 'len')
    if (length(chunksizes) > 1) {
      chunksizes[-1] <- 1
    }
  } else {
    chunksizes <- NA
  }

  # Put in blank strings for the units.  We will overwrite this
  # later with the actual units, if they have been passed in as
  # attributes.
  ncdf4::ncvar_def(name=varname,
                   units="",
                   dim=vardims,
                   missval=var_fill(varname, vals, prec),
                   prec=var_prec(varname, vals, prec),
                   compression=ifelse(compress, 1, NA),
                   chunksizes=chunksizes)

}

create_vars <- function(vars, dims, ids, prec, extra_dims, compress) {
  regular_var_names <- names(vars)[!(names(vars) %in% names(dims))]

  ncvars <- sapply(regular_var_names, function(varname) {
    create_var(dims, varname, vars[[varname]], prec, compress)
  }, simplify=FALSE)

  # Add a CRS var
  if (!is.null(dims$lat)) {
    ncvars$crs <- ncdf4::ncvar_def(name="crs", units="", dim=list(), missval=NULL, prec="integer")
  }

  # Manually create dimension variable for character IDs
  if (!is.null(dims$id) && mode(ids) == 'character') {
    ncvars$id <- create_char_dimension_variable(dims[['id']], 'id', ids)
  }

  for (dimname in names(extra_dims)) {
    vals <- extra_dims[[dimname]]
    if (mode(vals) == 'character') {
      ncvars[[dimname]] <- create_char_dimension_variable(dims[[dimname]], dimname, vals)
    }
  }

  return(ncvars)
}

#' Flip the first two dimensions of a multidimensional array
#' @param arr an array whose dimensions should be flipped
#' @return the transformed array
flip_first_two_dims <- function(arr) {
  ndim <- length(dim(arr))
  if (ndim > 2) {
    permut <- c(2, 1, 3:ndim)
  } else {
    permut <- c(2, 1)
  }

  aperm(arr, permut)
}
