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

#' Get a function to compute a named statistic over a vector of observations
#'
#' @param name name of statistic. Supported statistics are:
#' \describe{
#' \item{min}{minimum defined value}
#' \item{max}{maximum defined value}
#' \item{ave}{mean defined value}
#' \item{median}{median defined value}
#' \item{qXX}{quantile \code{XX} of defined values}
#' }
#' @export
find_stat <- function(name) {
  name <- tolower(name)

  if (name == 'min')
    return(stack_min)

  if (name == 'median')
    return(stack_median)

  if (name == 'max')
    return(stack_max)

  if (name == 'sum')
    return(stack_sum)

  if (name == 'ave')
    return(stack_mean)

  if (name == 'fraction_defined')
    return(stack_frac_defined)

  if (name == 'fraction_defined_above_zero')
    return(stack_frac_defined_above_zero)

  if (grepl('q\\d{1,2}(.\\d+)?$', name)) {
    q <- 0.01 * as.numeric(substring(name, 2))
    return(function(x) { stack_quantile(x, q) })
  }

  stop("Unknown stat ", name)
}

unless_all_na <- function(fn) {
  function(x, ...) ifelse(all(is.na(x)), as.numeric(NA), fn(x, ...) )
}
