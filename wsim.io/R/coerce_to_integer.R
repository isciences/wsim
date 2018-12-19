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

coerce_to_integer <- function(vals) {
  if (is.integer(vals)) {
    return(vals)
  }

  suppressWarnings(int_vals <- as.integer(vals))
  errors <- sum(is.na(int_vals)) - sum(is.na(vals))
  if (errors > 0) {
    stop("Values ", "(", errors, ") cannot be coerced to integers (examples: ",
         paste(utils::head(vals[is.na(int_vals) & !is.na(vals)], 3), collapse=", "), ")")
  }
  if (any(int_vals != vals, na.rm=TRUE)) {
    stop("Values (", sum(int_vals != vals, na.rm=TRUE), ") cannot be coerced to integers.")
  }

  return(int_vals)
}

#' Test if values can be stored as integers without loss
#'
#' @param vals a vector of values to test
#' @return \code{TRUE} if \code{vals} can be cast to integers without loss
#' @export
can_coerce_to_integer <- function(vals) {
  if (is.integer(vals)) {
    return(TRUE)
  }

  suppressWarnings(int_vals <- as.integer(vals))
  return(all(is.na(int_vals) == is.na(vals)) &&
         all(int_vals == vals, na.rm=TRUE))
}
