# Copyright (c) 2018-2019 ISciences, LLC.
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
#' @param blue_water        observed blue water
#' @param blue_water_median median blue water
#' @return lost fraction of expected hydropower generation
#' @export
hydropower_loss <- function(blue_water, blue_water_median) {
  stopifnot(length(blue_water_median) %in% c(1, length(blue_water)))
  
  ifelse(is.nan(blue_water),
         NA_real_,
         ifelse(rep.int(blue_water_median > 0, length(blue_water)),
                1 - pmax(pmin(1.013446 + 0.281561*log(blue_water / blue_water_median), 1.0), 0.0), 
                0))
}
