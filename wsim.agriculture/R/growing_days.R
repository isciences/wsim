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

#' Calculate number of growing days during an interval
#' 
#' @param from        first day of year in interval
#' @param to          second day of year in interval
#' @param plant_date  planting date
#' @param harvest_day harvest date
#' @return number of days within growing season
#' @export
growing_days <- function(from, to, plant_date, harvest_date) {
  if (from <= to)
    days <- from:to
  else
    days <- c(from:365, 1:to)
    
  if (is.matrix(plant_date))
    array(rowSums(sapply(days, 
                         function(d) 
                           is_growing_season(d, plant_date, harvest_date)),
                  na.rm=TRUE),
          dim=dim(plant_date)) + 0*plant_date
  else
    sum(sapply(days, 
               function(d)
                 is_growing_season(d, plant_date, harvest_date)))
}