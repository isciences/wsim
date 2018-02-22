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

#' Generate a netCDF populated with data from a generator
#'
#' @param fname    of the generated netCDF
#' @param varnames character vector of variable names
#'                 to write to \code{fname}
#' @param generator a function that will be called with
#'                  no arguments to produce values to
#'                  populate the variables
#' @param nrow      number of rows in the generated
#'                  netCDF
#' @param ncol      number of columns in the generated
#'                  netCDF
#' @inheritParams write_vars_to_cdf
#'
#' @export
generate_raster <- function(fname, varnames=c("data"), generator=stats::runif, nrow=18, ncol=36, extent=c(-180, 180, -90, 90), attrs=list(), append=FALSE) {
  data <- lapply(varnames, function(x) {
    matrix(generator(nrow*ncol), nrow=nrow)
  })

  names(data) <- varnames

  write_vars_to_cdf(data,
                    fname,
                    extent=extent,
                    attrs=attrs,
                    append=append)
}
