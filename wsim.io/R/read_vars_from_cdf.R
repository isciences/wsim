# Copyright (c) 2018-2019 ISciences, LLC.
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

BUILTIN_ATTRIBUTES = c('class', 'dim', 'dimnames', 'names')

#' Read all variables from a netCDF file
#'
#' @inheritParams parse_vardef
#' @inheritParams read_vars
#' @param vars A list of variables to read.  If NULL (default),
#'             all variables will be read.
#' @param as.data.frame return data in a data frame
#' @return structure described in \code{\link{read_vars}}, or a data frame
#' @export
read_vars_from_cdf <- function(vardef, vars=as.character(c()), offset=NULL, count=NULL, extra_dims=NULL, as.data.frame=FALSE) {
  stopifnot(is.null(offset) == is.null(count))
  if (!is.null(offset)) {
    stopifnot(length(offset) == length(count))
  }

  if (!is.null(offset) && !is.null(extra_dims)) {
    stop("Can read count/offset and extra_dims, but not both.")
  }

  def <- parse_vardef(vardef)

  fname <- def$filename
  if (is.character(vars)) {
    vars <- lapply(vars, parse_var)
  }

  vars <- c(vars, def$vars)

  cdf <- ncdf4::nc_open(fname)

  is_spatial <- !("id" %in% names(cdf$dim))
  wrap_rows <- NULL
  extent <- NULL
  ids <- NULL

  if (is_spatial) {
    latname <- ifelse("lat" %in% names(cdf$dim), "lat", "latitude")
    lonname <- ifelse("lon" %in% names(cdf$dim), "lon", "longitude")

    lats <- ncdf4::ncvar_get(cdf, latname)
    lons <- ncdf4::ncvar_get(cdf, lonname)


    dlat <- ifelse(length(lats) >=2, abs(lats[2] - lats[1]), 0)
    dlon <- ifelse(length(lons) >=2, abs(lons[2] - lons[1]), 0)

    if (!is.null(offset)) {
      # We want to interpret the offset and count relative to the final arrangement,
      # taking into account y-flipping
      if (lats[1] < lats[2]) {
        offset[2] <- length(lats) - (offset[2] + count[2] - 2)
      }

      lats <- ncdf4::ncvar_get(cdf, latname, start=offset[2], count=count[2])
      lons <- ncdf4::ncvar_get(cdf, lonname, start=offset[1], count=count[1])
    }

    # Figure out whether we need to adjust a 0-360 dataset to -180-180
    if (any(lons > 181)) {
      # Hack to handle CFS files using grid corners instead of centers
      if (lons[1] == 0 && lons[length(lons)] == 359.5) {
        lons <- lons + 0.5*dlon
      }

      wrap_rows <- which(lons > 180)
      lons <- c(lons[lons > 180] - 360, lons[lons < 180])
    }

    # Do we need to flip latitudes?
    flip_latitudes <- length(lats) > 1 && (lats[1] < lats[2])

    extent <- c(min(lons) - dlon/2,
                max(lons) + dlon/2,
                min(lats) - dlat/2,
                max(lats) + dlat/2)
  } else {
    if (!is.null(offset)) {
      stopifnot(length(offset) == 1)
      ids <- ncdf4::ncvar_get(cdf, "id", start=offset, count=count)
    } else {
      ids <- ncdf4::ncvar_get(cdf, "id")
    }
  }

  global_attrs <- ncdf4::ncatt_get(cdf, 0)

  data <- list()

  vars <- check_var_list(cdf, vars)
  vars_to_read <- sapply(vars, `[[`, 'var_in')
  real_dims <- shared_dimensions(cdf, vars_to_read)

  # Make sure right number of extra dimensions were specified. For spatial data we require all
  # extra dimensions to be constrained, so that we read in a matrix no matter what. For non-spatial
  # data we don't care; it all just ends up in a data frame anyway.

  if (is.null(offset) & is_spatial) {

    # If any dims are constant (and not a single line of lat or single meridian of lon),
    # then count those as extra dims
    dims_lengths    <- sapply(names(cdf$dim), function(x){
      length(cdf$dim[[x]]$vals)
    })
    potential_degen <- which(dims_lengths == 1)
    additional_extra_dim_names <- c(names(potential_degen)[!names(potential_degen) %in% c(latname, lonname)])

    if(length(additional_extra_dim_names) > 0){
      # get extra_dims = list(<name>=<values>)
      additional_extra_dims <- lapply(additional_extra_dim_names, function(varname) ncdf4::ncvar_get(cdf, varname))
      names(additional_extra_dims)     <- additional_extra_dim_names
      extra_dims <- c(extra_dims, additional_extra_dims)
    }

    expected_extra_dims <- length(real_dims) - 2
    if (length(extra_dims) != expected_extra_dims) {
      stop(sprintf("Expected %d extra dimensions but got %d.", expected_extra_dims, length(extra_dims)))
    }
  }

  if (!is.null(extra_dims)) {
    offset <- find_offset(cdf, real_dims, extra_dims)
    count <- find_count(real_dims, extra_dims)
  }

  for (var in cdf$var) {
    var_name <- var$name
    if(var_name %in% vars_to_read){
      # Read this as a regular variable
      if (is.null(offset)) {
        d <- ncdf4::ncvar_get(cdf, var_name)
      } else {
        # Collapse 3D array to 2D array, but don't
        # collapse a column (e.g., single meridian of longitude)
        # to a vector
        collapse <- !is.na(count[3]) && count[3] == 1

        d <- ncdf4::ncvar_get(cdf,
                              var_name,
                              start=offset,
                              count=count,
                              collapse_degen=collapse)
      }

      if (!is.null(wrap_rows)) {
        d <- rbind(d[wrap_rows, ], d[-wrap_rows, ])
      }

      if (is_spatial && !as.data.frame) {
        d <- t(d)
        if (flip_latitudes) {
          d <- apply(d, 2, rev)
        }
      }

      attrs <- ncdf4::ncatt_get(cdf, var$name)
      for (k in names(attrs)) {
        attr(d, k) <- attrs[[k]]
      }

      var_to_load <- Find(function(v) { v$var_in == var$name }, vars)
      data[[var_to_load$var_out]] <- perform_transforms(d, var_to_load$transforms)
    } else if (var$ndims == 0) {
      # This variable has no dimensions, and is
      # only used to store attributes.  Read the
      # attributes and put them in with the global
      # attributes.

      var_attrs <- ncdf4::ncatt_get(cdf, var$name)
      global_attrs[[var$name]] <- var_attrs
    }
  }

  if (as.data.frame) {
    dimension_vals <- list()
    for (i in 1:length(real_dims)) {
      d <- cdf$dim[[real_dims[[i]]]]

      if (is.null(offset) || count[i] == -1) {
        dimension_vals[[d$name]] <- d$vals
      } else {
        dimension_vals[[d$name]] <- d$vals[offset[i]:(offset[i]+count[i]-1)]
      }
    }

    dim_df_cols <- do.call(combos, dimension_vals)
    # Sort dim columns to correspond to the order in which values are written to disk
    dim_df_cols <- dim_df_cols[do.call(order,
                                       lapply(rev(names(dimension_vals)), function(d)
                                         match(dim_df_cols[[d]], dimension_vals[[d]]))), names(dimension_vals), drop=FALSE]

    # Prevent recyling in cbind if subsetting went awry
    stopifnot(all(sapply(data, length) == nrow(dim_df_cols)))

    df <- cbind(dim_df_cols,
                lapply(data, as.vector),
                stringsAsFactors=FALSE)

    # Sort left-right
    df <- df[do.call(order,
                     lapply(names(dimension_vals), function(d)
                       match(dim_df_cols[[d]], dimension_vals[[d]]))), , drop=FALSE]

    row.names(df) <- NULL

    # Copy global attributes over to data frame
    for (attrname in names(global_attrs)) {
      if (!(attrname %in% BUILTIN_ATTRIBUTES))
        attr(df, attrname) <- global_attrs[[attrname]]
    }

    # Copy variable attributes over to data frame
    for (varname in names(data)) {
      for (attrname in names(attributes(data[[varname]]))) {
        if (!(attrname %in% BUILTIN_ATTRIBUTES)) {
          attr(df[[varname]], attrname) <- attr(data[[varname]], attrname)
        }
      }
    }

    attr(df, 'dimvars') <- names(dimension_vals)

    # TODO revisit whether these are actually needed on a data frame
    if (is_spatial) {
      attr(df, 'extent') <- extent
    } else {
      attr(df, 'id') <- ids
    }

    ncdf4::nc_close(cdf)
    return(df)
  } else {
    ncdf4::nc_close(cdf)
    return(list(
      attrs= global_attrs,
      data= data,
      extent= extent,
      ids= ids
    ))
  }
}

#' Given a netCDF file handle and a list of variable names,
#' return the names of the dimensions that are shared among
#' all variables.
#' @param cdf      a ncdf4 file handle
#' @param varnames variable names to be included in the scan
#' @return a list of dimension names that are common to all
#'         variables in \code{varnames}
shared_dimensions <- function(cdf, varnames) {
  dim_counts <- list()
  for (varname in varnames) {
    var <- cdf$var[[varname]]
    for (dim in var$dim) {
      if (is.null(dim_counts[[dim$name]])) {
        dim_counts[[dim$name]] <- 1
      } else {
        dim_counts[[dim$name]] <- dim_counts[[dim$name]] + 1
      }
    }
  }

  shared_dims <- Filter(function(dimname) {
    dim_counts[[dimname]] == length(varnames)
  }, names(dim_counts))

  # TODO guard against pathological case where variables are
  # declared against same dimensions but in a different order?

  return(shared_dims)
}

#' Get a list of variables that can be read from a netCDF file
#'
#' A list of requested variable names can be provided.
#'
#' @param cdf  ncdf4 file handle
#' @param vars a (possibly-empty) list of var objects to read from \code{cdf}
#' @return a list of \code{var} objects.
check_var_list <- function(cdf, vars) {
  # Get a list of all dimensional vars in the file
  cdf_vars <- lapply(Filter(function(var) {
    var$ndims > 0
  }, cdf$var), function(var) var$name)

  # If no vars are specified, use all of the vars
  if (is.null(vars) || length(vars) == 0) {
    vars <- lapply(cdf_vars, make_var)
  } else {
    # Check that all requested vars can be found in the file
    for (var in vars) {
      if (!(var$var_in %in% cdf_vars))
        stop("Could not find var ", var$var_in, " in ", cdf$filename)
    }
  }

  if (length(vars) == 0) {
    stop("No vars found to load in ", cdf$filename)
  }

  return(vars)
}

#' Compute the offset vector for specified values of dimensions
#'
#' @param cdf        a ncdf4 file handle
#' @param real_dims  a list of dimensions
#' @param dim_values a list whose keys represent dimension names and values
#'                   represent values along those dimensions
find_offset <- function(cdf, real_dims, dim_values) {
  sapply(real_dims, function(dimname) {
    if (dimname %in% names(dim_values)) {
      i <- which(ncdf4::ncvar_get(cdf, dimname)==dim_values[[dimname]])
      if (length(i) == 0) {
        stop(sprintf("Invalid value \"%s\" for dimension \"%s\".", dim_values[[dimname]], dimname))
      }
      return(i)
    } else {
      return(1)
    }
  }, simplify=TRUE)
}

#' Compute the count vector for specified valuws of dimensions
#'
#' @inheritParams find_offset
find_count <- function(real_dims, dim_values) {
  ifelse(real_dims %in% names(dim_values), 1, -1)
}
