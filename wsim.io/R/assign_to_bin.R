#' Assign a value to one of several bins.
#'
#' Values less than the smallest bin value are assigned to that
#' value. Values greater than the largest bin value are assigned
#' to that value.
#'
#' @param vals Values to be assigned to a bin
#' @param bins Bin values
#' @return a bin corresponding to each of \code{vals}
#' @export
assign_to_bin <- function(vals, bins) {
  bins <- sort(bins)
  bins[findInterval(vals, c(bins, Inf), all.inside=TRUE)]
}
