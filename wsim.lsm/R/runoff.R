#' Runoff by Thornthwaite water balance equation
#'
#' @param P Effective precipication [L]
#' @param E Evapotranspiration [L]
#' @param dWdt Change in soil moisture [L]
#' @return runoff [L]
runoff <- function(P, E, dWdt) {
	  P - E - dWdt
}
