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

#' Determine if a given day is within the growing season
#' 
#' @param day_of_year  numerical day of year, 1-365
#' @param plant_date   day of year when planting occurs
#' @param harvest_date day of year when harvest occurs
#' @return            TRUE if day is within growing season, FALSE otherwise
#' @export
is_growing_season <- function(day_of_year, plant_date, harvest_date) {
  if (harvest_date > plant_date)
    day_of_year >= plant_date & day_of_year <= harvest_date
  else
    day_of_year >= plant_date | day_of_year <= harvest_date
}
