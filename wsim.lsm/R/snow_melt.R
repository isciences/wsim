#' Calculate snowmelt
#' @param snowpack: Snowpack (mm)
#' @param T: Average temp (C)
#' @param z: Elevation (m)
#' @return: Snowmelt (mm/month)
snow_melt <- function(snowpack, melt_month, T, z) {
  ifelse(!is.na(T) & T >= -1, 
         ifelse(z <= 500,
                1.0, 
                ifelse(melt_month == 1, 
                       0.5,
                       1.0)),
         0.0) * snowpack
  #ifelse(T < -1,
  #       0.0,
  #       ifelse(is.na(z) | z <= 500,
  #              snowpack,
  #              ifelse(melt_month == 1,
  #                     0.5*snowpack,
  #                     snowpack)))
}
