# Copyright (c) 2020 ISciences, LLC.
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

#' Set names of specified dimension
#'
#' @param x     array
#' @param dim   dimension number (e.g., \code{1}, \code{2})
#' @param names character vector of names
#' @return \code{x} with updated dimension names
#' @export
set_dimnames <- function(x, dim, names) {
  dimnames(x)[[dim]] <- names
  x
}

#' Update names of specified dimension
#'
#' @param x   array
#' @param dim dimension number (e.g., \code{1}, \code{2})
#' @param fun function called with previous dimensions names
#'            and returning updated dimension names
#' @return \code{x} with updated dimension names
#' @export
update_dimnames <- function(x, dim, fun) {
  set_dimnames(x, dim, fun(dimnames(x)[[dim]]))
}
