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

#' Estimate hydropowerloss based on blue water
#'
#' @param blue_water observed blue water
#' @param expected   blue water (e.g., location parameter of fitted distribution)
#' @export
hydropower_loss <- function(blue_water, blue_water_expected, exponent) {
  stopifnot(length(blue_water) == length(blue_water_expected)) 
  
  ifelse(is.nan(blue_water),
         NA_real_,
         ifelse(blue_water_expected > 0,
                1 - pmax(pmin((blue_water / blue_water_expected) ^ exponent, 1.0), 0.0), 
                0))
}
