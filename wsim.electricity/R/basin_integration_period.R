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
#' @param upstream_capacity     upstream storage capacity available for electric
#'                              power generation
#' @param expected_monthly_flow typical monthly total blue water, e.g., the location
#'                              parameter of a fitted distribution
#' @param available_periods     vector of available integration periods in months              
#' @export
basin_integration_period <- function(upstream_capacity, expected_monthly_flow, available_periods) {
  ifelse(is.na(upstream_capacity) | is.na(expected_monthly_flow) | expected_monthly_flow == 0,
         available_periods[1],
         available_periods[findInterval(upstream_capacity / expected_monthly_flow,
                                        c(available_periods, Inf),
                                        all.inside=TRUE)])
}