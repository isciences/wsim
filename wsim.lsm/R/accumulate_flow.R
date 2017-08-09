#' @useDynLib wsim.lsm, .registration=TRUE
#' @export
accumulate_flow <- function(weights, directions) {
  fa_vals <- calculateFlow(raster::nrow(weights),
                           raster::ncol(weights),
                           raster::values(directions),
                           raster::values(weights))
  return(fa_vals + raster::values(weights))
}
