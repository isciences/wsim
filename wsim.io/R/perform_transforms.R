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
