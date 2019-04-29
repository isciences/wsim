# Copyright (c) 2019 ISciences, LLC.
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

#' Get the values of the dimensions associated with a variable in a netCDF file
#'
#' @param vardef       filename/variable to check
#' @param exclude.dims dimensions to ignore in output
#' @return a list with names representing dimension names and values
#'         representing dimension values
#' @export
read_dimension_values <- function(vardef, exclude.dims=NULL) {
  parsed_vardef <- parse_vardef(vardef)

  stopifnot(file.exists(parsed_vardef$filename))

  if (!endsWith(parsed_vardef$filename, '.nc'))
    return(list())

  if (length(parsed_vardef$vars) > 0) {
    var <- parsed_vardef$vars[[1]]$var_in
  } else {
    var <- 1
  }

  nc <- ncdf4::nc_open(parsed_vardef$filename)
  dimnames <- sapply(nc$var[[var]]$dim, function(d) d$name)
  dimnames <- dimnames[!dimnames %in% exclude.dims]

  ret <- lapply(dimnames, function(d) ncdf4::ncvar_get(nc, d))
  names(ret) <- dimnames

  ncdf4::nc_close(nc)
  return(ret)
}
