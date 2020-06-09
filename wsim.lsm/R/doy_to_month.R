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

#' Return the month associated with a given day of year
#'
#' Does not account for leap years
#'
#' @param doy day of year
#' @return integer month associated with \code{doy}
#' @export
doy_to_month <- function(doy) {
  res <- doy # copy input to get same dimensions
  res[] <- .doy_vec[doy]
  res
}

.doy_vec <- sapply(1:365,
                   function(doy) {
                     as.integer(strftime(as.Date(doy - 1, origin='1999-01-01'), '%m'))
                   })
