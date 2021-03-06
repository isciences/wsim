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

#' Determine the number of days since planting
#' 
#' @inheritParams is_growing_season
#' @return number of days since planting or \code{NA_integer_} if 
#'         \code{day_of_year} is outside the growing season.
#' @export
days_since_planting_r <- function(day_of_year, plant_date, harvest_date) {
  as.integer(
    ifelse(
      is_growing_season(day_of_year, plant_date, harvest_date),
      ifelse(harvest_date > plant_date | day_of_year >= plant_date,
             day_of_year - plant_date,
             365 - plant_date + day_of_year),
      NA_integer_
    )
  )
}
