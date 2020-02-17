# Copyright (c) 2018-2020 ISciences, LLC.
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

#' Read distribution fit files and store them in a list
#'
#' Throws an error if any of the following conditions apply:
#' 1) Extents of multiple fit files do not match
#' 2) A fit file has an undefined distribution
#' 3) A fit file has an undefined variable
#'
#' @param files filenames representing netCDF files with distribution parameters
#' @return a list with one 3d array per distribution, keyed on variable name
#' @export
read_fits_from_cdf <- function(files) {
  fits <- list()

  extent <- NULL

  for (file in files) {
    if (isTRUE(peek_distribution(file) == 'nonparametric')) {
      fit <- read_nonparametric(file)
    } else {
      fit <- read_parametric(file)
    }

    attr(fit, 'filename') <- file

    var <- attr(fit, 'variable')
    distribution <- attr(fit, 'distribution')

    if (is.null(extent)) {
      extent <- attr(fit, 'extent')
      stopifnot(!is.null(extent))
    } else {
      stopifnot(extent == attr(fit, 'extent'))
    }

    if (is.null(var)) {
      stop("Unknown variable name in fit file", file)
    }

    if (is.null(distribution)) {
      stop("Unknown distribution in fit file", file)
    }

    fits[[var]] <- fit
    wsim.io::info(sprintf("Read distribution parameters for %s (%s)", var, attr(fit, 'distribution')))
  }

  return(fits)
}

read_global_att <- function(nc, attname) {
  att <- ncdf4::ncatt_get(nc, 0, attname)
  if (att$hasatt) {
    return(att$value)
  } else {
    return(NULL)
  }
}

peek_distribution <- function(fname) {
  nc <- ncdf4::nc_open(fname)
  dist <- read_global_att(nc, 'distribution')
  ncdf4::nc_close(nc)
  return(dist)
}

read_parametric <- function(fname) {
  read_vars_to_cube(fname, attrs_to_read=c('distribution', 'variable', 'units'))
}

read_nonparametric <- function(fname) {
  nc <- ncdf4::nc_open(fname)

  obs <- aperm(ncdf4::ncvar_get(nc, 'ordered_values'), c(2, 1, 3))
  for (attname in c('variable', 'distribution', 'units')) {
    attr(obs, attname) <- read_global_att(nc, attname)
  }
  attr(obs, 'extent') <- get_extent(nc)

  ncdf4::nc_close(nc)

  return(obs)
}

