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

#' Select an integration period for a basin
#' 
#' @param cumulative_capacity   storage capacity available for electric power 
#'                              generation (capacity from reservoirs in a basin,
#'                              plus all upstream basins)
#' @param expected_monthly_flow median monthly total blue water
#' @param available_periods     vector of available integration periods in months
#'                              flows will be assigned to bins as follows:
#                               1:      flow < 3
#                               3: 3 <= flow < 6
#                               6: 6 <= flow
#' @export
basin_integration_period <- function(upstream_capacity, expected_monthly_flow, available_periods) {
  ifelse(is.na(expected_monthly_flow) | is.na(upstream_capacity) | expected_monthly_flow <= 0,
         available_periods[1], 
         wsim.io::assign_to_bin(upstream_capacity / expected_monthly_flow, available_periods))
}