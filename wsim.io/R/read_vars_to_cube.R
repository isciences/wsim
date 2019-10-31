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
  ids <- vars[[1]]$ids

  for (var in vars) {
    if (!all(var$extent == extent)) {
      stop("Cannot create cube from layers with unequal extents.")
    }

    if (!all(var$ids == ids)) {
      stop("Cannot create cube from layers inconsistent ids.")
    }
  }

  data <- do.call(c, lapply(vars, `[[`, 'data'))
  data <- lapply(data, function(d) { if (!is.matrix(d)) t(d) else d })

  cube <- abind::abind(data, along=3)
  dimnames(cube) <- list(NULL, NULL, as.vector(sapply(vars, function(var) names(var$data))))

  attr(cube, 'extent') <- extent
  attr(cube, 'ids') <- ids

  for (att in lapply(attrs_to_read, parse_attr)) {
    attr(cube, att$key) <- find_attr(vars[[1]], att)
  }

  return(cube)
}

find_attr <- function(data, att) {
  if (is.null(att$var)) {
    # No source variable specified.
    # First, try to read a global attribute.
    val <- data$attrs[[att$key]]
    if (!is.null(val)) {
      return(val)
    }

    # Didn't find it as a global attribute.
    # Start looking through the regular variables.
    for (var in names(data$data)) {
      val <- attr(data$data[[var]], att$key)
      if (!is.null(val)) {
        return(val)
      }
    }

    # Try checking no-data variables
    for (a in data$attrs) {
      if (is.list(a)) {
        val <- a[[att$key]]
        if (!is.null(val)) {
          return(val)
        }
      }
    }

    return(NULL)
  } else {
    # Is the variable a regular variable?
    if (att$var %in% names(data$data)) {
      return(attr(data$data[[att$var]], att$key))
    }

    # Is it a no-data variable?
    if (att$var %in% names(data$attrs) && is.list(data$attrs[[att$var]])) {
      return(data$attrs[[att$var]][[att$key]])
    }

    return(NULL)
  }
}
