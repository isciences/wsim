#' Estimate initial crop fraction remaining based on quadratic regression
#' 
#' @param season_length growing season length in days
#' @param a             regression coefficient of \code{season_length}
#' @param b             regression coefficient of \code{season_length^2}
#' @return initial crop fraction remaining
#' 
#' @export
initial_crop_fraction_remaining <- function(season_length, a, b) {
  1 / (1 - season_length*a - season_length*season_length*b)
}
