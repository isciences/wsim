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

#' Estimate loss multiplier due to growth stage
#'
#' @inheritParams is_growing_season
#' @param  early_loss_factors two-column matrix where first column represents
#'                            days since planting and second column represents
#'                            a loss multiplier
#' @param  late_loss_factors  two-column matrix where first column represents
#'                            days until harvest and second column represents
#'                            a loss multiplier
#' @return loss multiplier
#' @export
growth_stage_loss_multiplier <- function(day_of_year, plant_date, harvest_date, early_loss_factors, late_loss_factors) {
  # TODO: hash out details of whether these functions should be stepwise
  # or linearly interpolated.
  
  if (nrow(early_loss_factors) > 0) {
    early_loss_fn <- stats::approxfun(
      x=early_loss_factors[,1],
      y=early_loss_factors[,2],
      yleft=1,
      yright=1
    )
  } else {
    early_loss_fn <- function(...) 1
  }
  
  if (nrow(late_loss_factors) > 0) {
    late_loss_fn <- stats::approxfun(
      x=late_loss_factors[,1],
      y=late_loss_factors[,2],
      yleft=1,
      yright=1
    )
  } else {
    late_loss_fn <- function(...) 1
  }
  
  pmax(early_loss_fn(days_since_planting(day_of_year, plant_date, harvest_date)),
       late_loss_fn(days_until_harvest(day_of_year, plant_date, harvest_date)))
}