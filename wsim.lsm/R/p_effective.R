#' Calculate the effective (net) precipitation
#'
#' @param Pr Measured precipitation (mm/month)
#' @param Sa Snow accumulation (mm/month)
#' @param Sm Snow melt (mm/month)
#' @return Effective (net) precipitation
#' @export
P_effective <- function(Pr, Sa, Sm) {
  coalesce(Sm, 0) + (Pr - Sa)
}
