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

#' Check the units of data read by \code{read_vars_from_cdf}
#' 
#' If the units are undefined, a warning will be issued.
#' If the units are incorrect, a the program will exit.
#' 
#' @param data           object returned by \code{read_vars_from_cdf}
#' @param var            name of variable to check
#' @param expected_units expected units of variable (e.g., 'mm')
#' @param fname          filename from which variable was read (used for
#'                       creating an error message only)
#' @return nothing
#' @export
check_units <- function(data, var, expected_units, fname) {
  units <- attr(data$data[[var]], 'units') 
  
  if (is.null(units)) {
    warn("Undefined units for variable", var, "in", fname, ".")
  } else if (units != expected_units) {
    die_with_message("Unexpected units for variable", var, "in", fname,
                     "( expected", expected_units, "got", units, ")")
  }

}
