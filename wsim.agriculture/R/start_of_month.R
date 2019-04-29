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

start_days <- c(1,  32, 60, 91,  121, 152, 182, 213, 244, 274, 305, 335)

#' Provide the day of the year of the first day in a month
#' 
#' Does not consider leap years.
#' @param month month [1-12]
#' @return day of year
#' @export
start_of_month <- function(month) {
  start_days[month]  
}
