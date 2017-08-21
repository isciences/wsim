#' @useDynLib wsim.lsm, .registration=TRUE
#' @export
accumulate_flow <- function(weights, directions) {
  fa_vals <- calculateFlow(directions, weights)
  return(fa_vals + weights)
}
