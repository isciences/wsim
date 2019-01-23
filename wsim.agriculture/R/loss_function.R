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

#' Estimate loss due to stress (water surplus/water deficit/heat/cold)
#'
#' @param  rp return period (positive) of stress
#' @return loss fraction (0 to 1)
#' @export
loss_function <- function(rp) {
  # An earlier version of the agricultural assessment included an exponential
  # damage function that could be parameterized according to the return periods
  # associated with the onset of loss, 50% loss, and complete loss. However,
  # these parameters were taken to be constant for all types of stresses.
  # With these constant parameters, the function is equivalent to the simplified
  # power function used here. This can be changed in the future if there is a 
  # need to parameterize the loss function further.
  rp_total <- 70 # return period associated with total loss
  rp_onset <- 6  # return period at onset of loss
  
  ifelse(rp >= 70,
         1,
         ifelse(rp <= 6,
                0,
                1 - ((rp_total - rp)/(rp_total - rp_onset))^1.4))
}
