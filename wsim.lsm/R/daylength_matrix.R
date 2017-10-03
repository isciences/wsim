#' Compute a matrix of monthly average day length
#'
#' @param year  year for computation. Must be >= 1900
#' @param month month for computation
#' @param extent vector of \code{(xmin, xmax, ymin, ymax)}
#' @param nrows number of rows (latitudes) in generated matrix
#' @param ncols number of columns (longitudes) in generated matrix
#'
#' @return a matrix of specified dimensions, where each cell represents
#'         the day length as a fraction of 24 hours
#' @useDynLib wsim.lsm, .registration=TRUE
#' @export
daylength_matrix <- function(year, month, extent, nrows, ncols) {
  dlat <- (extent[4] - extent[3]) / nrows
  lats <- seq(from=extent[4] - dlat/2, to=extent[3] + dlat/2, by=-dlat)
  matrix(average_day_length(lats, year, month)/24, nrow=nrows, ncol=ncols)
}
