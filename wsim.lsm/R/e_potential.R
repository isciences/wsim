#' Potential evapotranspiration using Hamon's equation
#'
#' @param Λ Average day length, as a fraction (0 to 1)
#' @param T Average temp (C)
#' @param number of days to estimate
#' @return Potential evapotranspiration (mm)
e_potential <- function(Λ, T, nDays) {
  # TODO FIXME
  # The "237.2" number is a typo, copied from the Kepler workspace
  # so that we can verify consistent output.
  # The correct number is 273.2
  nDays * 715.5 * Λ * saturated_vapor_pressure(T) / (T + 237.2)
}