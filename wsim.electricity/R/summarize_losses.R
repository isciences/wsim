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

#' Summarize aggregated loss risks for multiple plants in a given boundary
#'
#' @param plants data frame of plants
#' @param loss   data frame of losses
#' @param aggfield field over which to aggregate
#' @return data frame with aggregated risks
#' @export
summarize_losses <- function(plants, loss, aggfield) {
  plants <-  dplyr::mutate(
    plants,
    reserve_capacity_mw= calculate_reserve_capacity(fuel=fuel,
                                                    water_cooled=water_cooled,
                                                    seawater_cooled=seawater_cooled,
                                                    capacity_mw=capacity_mw,
                                                    generation_mw=generation_mw)
  )
  
  suppressWarnings(
    plants <- dplyr::inner_join(plants, loss, by='id')
  )
  
  plants <- dplyr::filter(plants, !is.na(!!rlang::sym(aggfield)))
  plants <- dplyr::group_by(plants, !!rlang::sym(aggfield))
  
  dplyr::summarize(
    plants,
    capacity_tot_mw= sum(capacity_mw),
    generation_tot_mw= sum(generation_mw),
    capacity_reserve_mw= sum(reserve_capacity_mw),
    
    gross_loss_mw= sum(generation_mw*loss_risk),
    net_loss_mw= pmax(0, gross_loss_mw - capacity_reserve_mw),
    hydro_loss_mw= sum(ifelse(fuel=='Hydro', generation_mw*loss_risk, 0)),
    nuclear_loss_mw= sum(ifelse(fuel=='Nuclear', generation_mw*loss_risk, 0)),
    
    gross_loss_pct= gross_loss_mw / generation_tot_mw,
    net_loss_pct= net_loss_mw / generation_tot_mw,
    hydro_loss_pct= hydro_loss_mw / dplyr::na_if(sum(ifelse(fuel=='Hydro', generation_mw, 0)), 0),
    nuclear_loss_pct= nuclear_loss_mw / dplyr::na_if(sum(ifelse(fuel=='Nuclear', generation_mw, 0)), 0),
    
    reserve_utilization_pct= sum(gross_loss_mw - net_loss_mw) / dplyr::na_if(sum(reserve_capacity_mw), 0)
  )
}

calculate_reserve_capacity <- function(fuel, water_cooled, seawater_cooled, capacity_mw, generation_mw) {
  ifelse(fuel %in% c('Hydro', 'Wind', 'Solar', 'Geothermal', 'Wave and Tidal') | (water_cooled & !seawater_cooled),
         0.0,
         capacity_mw - generation_mw)
}

