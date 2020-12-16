#' Read a MIRCA2000 crop calendar file, converting subcrop area into area fraction.
#' 
#' @param fname filename to read
#' @return a data frame
#' @export
read_mirca_crop_calendar <- function(fname) {
  parse_mirca_condensed_crop_calendar(fname) %>%
    dplyr::group_by(unit_code, crop) %>%
    dplyr::mutate(tot_area = sum(area_ha)) %>%
    dplyr::filter(tot_area > 0) %>%
    dplyr::mutate(area_frac= area_ha / tot_area) %>%
    dplyr::select(unit_code, crop, subcrop, area_frac, plant_month, harvest_month) %>%
    as.data.frame()
}