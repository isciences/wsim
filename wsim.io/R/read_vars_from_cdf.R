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

#' Read all variables from a netCDF file
#'
#' @inheritParams parse_vardef
#' @inheritParams read_vars
#' @param vars A list of variables to read.  If NULL (default),
#'             all variables will be read.
#' @param extra_dims list containing names and values of extra dimensions
#'        along which a values at a single point should be extracted, e.g.
#'        \code{extra_dims=list(crop='maize', quantile=0.50)}. It provides
#'        a higher-abstraction alternative to the use of \code{offset} and
#'        \code{count}.
#' @return structure described in \code{\link{read_vars}}
#' @export
read_vars_from_cdf <- function(vardef, vars=as.character(c()), offset=NULL, count=NULL, extra_dims=NULL) {
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

    dlat <- abs(lats[2] - lats[1])
    dlon <- abs(lons[2] - lons[1])

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
    flip_latitudes <- FALSE

    if (!is.null(offset)) {
      stopifnot(length(offset) == 1)
      ids <- ncdf4::ncvar_get(cdf, "id", start=offset, count=count)
    } else {
      ids <- ncdf4::ncvar_get(cdf, "id")
    }
  }

  global_attrs <- ncdf4::ncatt_get(cdf, 0)

  data <- list()

  # Get a list of all dimensional vars in the file
  cdf_vars <- lapply(Filter(function(var) {
    var$ndims > 0
  }, cdf$var), function(var) var$name)

  # If no vars are specified, use all of the vars
  if (is.null(vars) || length(vars) == 0) {
    vars <- lapply(cdf_vars, make_var)
  }

  # Check that all requested vars can be found in the file
  for (var in vars) {
    if (!(var$var_in %in% cdf_vars))
      stop("Could not find var ", var$var_in, " in ", fname)
  }

  if (length(vars) == 0) {
    stop("No vars found to load in ", fname)
  }

  # TODO assert all vars have same dimensions
  dimnames <- sapply(cdf$var[[vars[[1]]$var_in]]$dim, function(d) d$name)

  # Make sure right number of extra dimensions were specified.
  if (is.null(offset)) {
    expected_extra_dims <- length(dimnames) - ifelse(is_spatial, 2, 1)
    if (length(extra_dims) != expected_extra_dims) {
      stop(sprintf("Expected %d extra dimensions but got %d.", expected_extra_dims, length(extra_dims)))
    }
  }

  if (!is.null(extra_dims)) {
    offset <- sapply(dimnames, function(dimname) {
      if (dimname %in% names(extra_dims)) {
        i <- which(cdf[['dim']][[dimname]][['vals']]==extra_dims[[dimname]])
        if (length(i) == 0) {
          stop(sprintf("Invalid value %s for dimension %s.", extra_dims[[dimname]], dimname))
        }
        return(i)
      } else {
        return(1)
      }
    })

    count <- ifelse(dimnames %in% names(extra_dims), 1, -1)
  }

  for (var in cdf$var) {
    if (var$ndims > 0) {
      # Read this as a regular variable
      for (var_to_load in vars) {
        if (var_to_load$var_in == var$name) {
          if (is.null(offset)) {
            d <- ncdf4::ncvar_get(cdf, var$name)
          } else {
            # Collapse 3D array to 2D array, but don't
            # collapse a column (e.g., single meridian of longitude)
            # to a vector
            collapse <- !is.na(count[3]) && count[3] == 1

            d <- ncdf4::ncvar_get(cdf,
                                  var$name,
                                  start=offset,
                                  count=count,
                                  collapse_degen=collapse)
          }

          if (!is.null(wrap_rows)) {
            d <- rbind(d[wrap_rows, ], d[-wrap_rows, ])
          }

          d <- t(d)
          if (flip_latitudes) {
            d <- apply(d, 2, rev)
          }

          attrs <- ncdf4::ncatt_get(cdf, var$name)
          for (k in names(attrs)) {
            attr(d, k) <- attrs[[k]]
          }

          data[[var_to_load$var_out]] <- perform_transforms(d, var_to_load$transforms)
        }
      }
    } else {
      # This variable has no dimensions, and is
      # only used to store attributes.  Read the
      # attributes and put them in with the global
      # attributes.

      var_attrs <- ncdf4::ncatt_get(cdf, var$name)
      global_attrs[[var$name]] <- var_attrs
    }
  }

  ncdf4::nc_close(cdf)

  return(list(
    attrs= global_attrs,
    data= data,
    extent= extent,
    ids= ids
  ))
}
