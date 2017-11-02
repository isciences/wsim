#' Apply a function to each pixel of a stack of matrices
#'
#' @param arr a three-dimensional array
#' @param fun a function to apply at each row and column of the input
#'            array. The function will be called with a vector of the
#'            z-values as a single argument.
#' @return an array containing the values returned by \code{fun} at
#'         each pixel
#' @export
array_apply <- function(arr, fun) {
  if (parallel_backend_exists()) {
    apply_fn <- parallel::parApply
  } else {
    apply_fn <- apply
  }

  return(aperm(apply_fn(X=arr, MARGIN=c(2,1), FUN=fun)))
}
