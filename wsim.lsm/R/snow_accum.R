#' Snow accumulation
#'
#' Compute snow accumulation, assuming that all precipitation
#' is snowfall if the temperature less than -1 C, and that no
#' precipitation is snowfall if the temperature is unknown or
#' greater than or equal to -1 C.
#'
#' @param Pr Measured precipitation (mm/day)
#' @param T  Average daily temperature (C)
#' @return snow accumulation in mm
#' @export
snow_accum <- function(Pr, T) {
  Pr * ifelse(!is.na(T) & T <= -1,
              1.0,
              0.0)
}
