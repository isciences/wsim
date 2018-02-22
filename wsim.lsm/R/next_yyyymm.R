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

#' Get the next month
#'
#' @param yyyymm Year/month in YYYYMM format
#' @return Following month in YYYYMM format
#' @export
next_yyyymm <- function(yyyymm) {
  first_day_of_current_month <- as.Date(paste0(yyyymm, '01'), '%Y%m%d')
  next_ymm <- strftime(first_day_of_current_month + 31, '%Y%m')

  leading_zeros <- paste(rep('0', nchar('YYYYMM') - nchar(next_ymm)), collapse='')
  return(paste0(leading_zeros, next_ymm))
}
