#' Apply named transformations to data
#'
#' @param data       a numeric vector or matrix
#' @param transforms a character vector of transformaiton
#'                   descriptions
#' @return a transformed version of \code{data}
perform_transforms <- function(data, transforms) {
  for (transform in transforms) {
    if (transform == "negate") {
      data <- -data
    } else if (transform == "fill0") {
      data[is.na(data)] <- 0
    } else {
      stop("Unknown transformation ", transforms)
    }
  }

  return(data)
}
