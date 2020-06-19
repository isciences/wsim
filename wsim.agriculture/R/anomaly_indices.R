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

#' Get the array index associated with the first month of observed data
#' 
#' @param months_obs number of months of observed data available, up to and
#'                   including the current month
#' @param model_months number of months used in the random forest mode
#' @param months_to_harvest number of months until the crop will be harvested
#'                          (\code{0} for a harvest this month)
#' @export
anomaly_start_indices <- function(months_to_harvest, model_months, months_obs) {
  months_to_harvest - model_months + months_obs + 1
}

