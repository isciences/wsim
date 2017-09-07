#' Saturated vapor pressure using Buck's equation
#'
#' @param Tm Daily mean temperature (C)
#' @return Vapor pressure (kPa)
#' @export
saturated_vapor_pressure <- function(Tm) {
  0.61121 * exp((18.678 - Tm / 234.5) * Tm / (257.14 + Tm))
}
