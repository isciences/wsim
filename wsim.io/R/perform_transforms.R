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
    } else if (startsWith(transform, '[') && endsWith(transform, ']')) {
      body <- substr(transform, 2, nchar(transform) - 1)

      # Explicitly create a new matrix whose dimensions match the original
      # This allows us to supply constant-valued functions such as [0] or [1]
      data <- matrix((function(x) eval(parse(text=body)))(data),
                     nrow=nrow(data),
                     ncol=ncol(data))
    } else {
      stop("Unknown transformation ", transforms)
    }
  }

  return(data)
}
