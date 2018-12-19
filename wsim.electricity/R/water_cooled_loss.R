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

#' Estimate water-cooled loss risk
#' 
#' @param x    total blue water return period
#' @param xc   return period at which loss risk begins to occur
#' @param xmax return period associated with complete loss risk
#' @export
water_cooled_loss <- function(x, xc, xmax) {
  A <- exp(log(101) / (xmax - xc))
  0.01*pmax(0, pmin(100, A^(x - xc) - 1))
}

#' Estimate onset of water-cooled loss
#' 
#' @param baseline_water_stress baseline water stress
#' @return return period at which losses begin
#' @export
water_cooled_loss_onset <- function(baseline_water_stress) {
  bins  <- c(0,  0.1, 0.2, 0.4, 0.8, 1.0)
  onset <- c(30,  25,  20,  15,  10,  10)
  
  interpolator <- stats::approxfun(bins, onset)
  ifelse(is.na(baseline_water_stress),
         max(onset),
         ifelse(baseline_water_stress > max(bins),
                min(onset),
                interpolator(baseline_water_stress)))
}