#' Compute evapotranspiration
#'
#' @param P Effective precipitation (mm/day)
#' @param E0 Potential evapotranspiration (mm/day)
#' @param dWdt Change in soil moisture(mm/day)
#' @return Evapotranspiration (mm/day)
#'
evapotranspiration <- function(P, E0, dWdt) {
  # Tech manual has P < E0, but Kepler has P <= E0
  # TODO make consistent
  ifelse(P <= E0, P - dWdt, E0)
}