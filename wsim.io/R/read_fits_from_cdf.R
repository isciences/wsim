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
    fit <- read_vars_to_cube(file, attrs_to_read=c('distribution', 'variable', 'units'))
    attr(fit, 'filename') <- file

    var <- attr(fit, 'variable')
    distribution <- attr(fit, 'distribution')

    if (is.null(extent)) {
      extent <- attr(fit, 'extent')
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

