#' Potential evapotranspiration using Hamon's equation
#'
#' @param lambda Average day length, as a fraction (0 to 1)
#' @param T Average temp (C)
#' @param nDays number of days to estimate
#' @return Potential evapotranspiration (mm)
#' @export
e_potential <- function(lambda, T, nDays) {
  nDays * 715.5 * lambda * saturated_vapor_pressure(T) / (T + 273.15)
}
