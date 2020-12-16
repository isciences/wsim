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

#' Create a grid of MIRCA subcrop area fractions
#' 
#' @param regions a matrix of \code{unit_code} values
#' @param calendar_df a MIRCA crop calendar data frame
#' @param crop_id a numeric MIRCA crop identifier
#' @param subcrop_id a numeric MIRCA subcrop identified
#' @return a grid of \code{area_frac} values
#' @export
mirca_area_fraction_grid <- function(regions, calendar_df, crop_id, subcrop_id) {
  default_area_frac_df <- create_default_area_frac_df(calendar_df)
  
  reclass_matrix <- default_area_frac_df %>%
    dplyr::left_join(calendar_df, by = c('unit_code', 'crop', 'subcrop')) %>%
    dplyr::filter(crop == crop_id,
                  subcrop == subcrop_id) %>%
    dplyr::mutate(area_frac = dplyr::if_else(is.na(area_frac),
                                             default_area_frac,
                                             area_frac)) %>%
    dplyr::select(unit_code, area_frac) %>%
    as.matrix(rownames.force = FALSE)
  
  reclassify(regions, reclass_matrix, na_default = TRUE)
}

#' Create a grid of MIRCA subcrop planting dates
#' 
#' @inheritParams mirca_area_fraction_grid
#' @return a grid of \code{plant_date} values (as day of year)
#' @export
mirca_plant_date_grid <- function(regions, calendar_df, crop_id, subcrop_id) {
  reclass_matrix <- calendar_df %>%
    dplyr::filter(crop == crop_id,
                  subcrop == subcrop_id) %>%
    dplyr::mutate(plant_doy = start_of_month(plant_month)) %>%
    dplyr::select(unit_code, plant_doy) %>%
    as.matrix(rownames.force = FALSE)
  
  reclassify(regions, reclass_matrix, na_default = TRUE)
}

#' Create a grid of MIRCA subcrop harvest dates
#' 
#' @inheritParams mirca_area_fraction_grid
#' @return a grid of \code{harvest_date} values (as day of year)
#' @export
mirca_harvest_date_grid <- function(regions, calendar_df, crop_id, subcrop_id) {
  reclass_matrix <- calendar_df %>%
    dplyr::filter(crop == crop_id,
                  subcrop == subcrop_id) %>%
    dplyr::mutate(harvest_doy = end_of_month(harvest_month)) %>%
    dplyr::select(unit_code, harvest_doy) %>%
    as.matrix(rownames.force = FALSE)
  
  reclassify(regions, reclass_matrix, na_default = TRUE)
}

#' Create a data frame that identifies provides a fallback area_frac if one
#' is not declared in the crop calendar.
#' 
#' If all subcrops have an undefined area fraction, the area fractions can
#' remain undefined. However, if only some subcrops have an undefined area
#' fraction, we coalesce the undefined values to zero. This is necessary to
#' create an area fraction grid that can be aggregated to a lower resolution.
#' If the NA values described above are not coalesced, then an aggregated
#' area fraction grid will have area fraction sums above 1.0.
#' 
#' @param calendar_df a MIRCA crop calendar data frame
#' @return a data frame with \code{unit_code}, \code{crop}, \code{subcrop}, \code{default_area_frac}
#' @export
create_default_area_frac_df <- function(calendar_df) {
  mirca_subcrops <- mirca_crops %>%
    dplyr::group_by(mirca_id) %>%
    dplyr::summarize(subcrop = seq(1, mirca_subcrops), .groups = 'drop') %>%
    dplyr::rename(crop = mirca_id)
  
  mirca_subcrops %>%
    tidyr::crossing(unit_code = calendar_df$unit_code) %>%
    dplyr::left_join(calendar_df, by = c('unit_code', 'crop', 'subcrop')) %>%
    dplyr::group_by(unit_code, crop) %>%
    dplyr::mutate(default_area_frac = dplyr::if_else(all(is.na(area_frac)),
                                                     NA_real_,
                                                     0.0)) %>%
    dplyr::select(unit_code, crop, subcrop, default_area_frac) %>%
    dplyr::ungroup()
}