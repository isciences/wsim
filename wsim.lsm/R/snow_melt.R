#' Calculate snowmelt
#'
#' Melting occurs when the temperature is greater than -1 C.
#' If elevation is less than 500 m, all snow will melt in one timestep.
#' If elevation is greater than 500m, snowmelt will be divided over
#' two timesteps.
#'
#' @param snowpack Snowpack (mm)
#' @param melt_month Number of consecutive months in which melting conditions
#'                   have been present
#' @param T Average temp (C)
#' @param z Elevation (m)
#' @return Snowmelt (mm/month)
#' @export
snow_melt <- function(snowpack, melt_month, T, z) {
  ifelse(!is.na(T) & T >= -1,
         ifelse(z <= 500,
                1.0,
                ifelse(melt_month == 1,
                       0.5,
                       1.0)),
         0.0) * snowpack
}
