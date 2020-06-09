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

#' Add or subtract months from a given month
#'
#' @param yyyymm Year/month in YYYYMM format
#' @param n      Number of months to add
#' @return year/month in YYYYMM format
#' @export
add_months <- function(yearmon, n) {
  year <- as.integer(substr(yearmon, 1, 4))
  month <- as.integer(substr(yearmon, 5, 6))

  month <- month + n

  while(month > 12) {
    month <- month - 12
    year <- year + 1
  }

  while(month < 1) {
    month <- month + 12
    year <- year - 1
  }

  sprintf('%04d%02d', year, month)
}
