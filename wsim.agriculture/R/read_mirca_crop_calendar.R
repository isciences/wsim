#' Read a MIRCA2000 crop calendar file, converting subcrop area into area fraction.
#' 
#' @param fname filename to read
#' @return a data frame
#' @export
read_mirca_crop_calendar <- function(fname) {
  parse_mirca_condensed_crop_calendar(fname) %>%
    group_by(unit_code, crop) %>%
    mutate(area_frac= area_ha/sum(area_ha)) %>%
    select(unit_code, crop, subcrop, area_frac, plant_month, harvest_month) %>%
    as.data.frame()
}