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

#' Read multiple variables to a 3D array
#'
#' @inheritParams read_vars
#'
#' @param vardefs a list or vector of variable definitions
#'                as described in \code{\link{parse_vardef}}
#' @param attrs_to_read a vector of global attribute names to be
#'                      read from the first variable definition
#'                      and attached as attributes to the returned
#'                      array.
#' @return a 3D array.  The dimnames of the third dimension
#'         will contain the variable names of the inputs, and
#'        the extent will be attached as an attribute.
#' @export
read_vars_to_cube <- function(vardefs, attrs_to_read=as.character(c()), offset=NULL, count=NULL) {
  vardefs <- lapply(vardefs, parse_vardef)
  vars <- lapply(vardefs, function(v) wsim.io::read_vars(v, offset=offset, count=count))
  extent <- vars[[1]]$extent

  for (var in vars) {
    if (!all(var$extent == extent)) {
      stop("Cannot create cube from layers with unequal extents.")
    }
  }

  data <- do.call(c, lapply(vars, `[[`, 'data'))

  cube <- abind::abind(data, along=3)
  dimnames(cube)[[3]] <- as.vector(sapply(vars, function(var) names(var$data)))

  attr(cube, 'extent') <- extent

  for (attr in attrs_to_read) {
    attr(cube, attr) <- vars[[1]]$attrs[[attr]]
  }

  return(cube)
}
