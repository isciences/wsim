#' Convert a 3D array to a list of matrices
#'
#' The dimnames of the 3rd dimension will be
#' used to name the elements of the returned
#' list.
#'
#' @param cube a 3-dimensional array
#' @return a list of matrices
#' @export
cube_to_matrices <- function(cube) {
  stopifnot(length(dim(cube)) == 3)

  vars <- lapply(1:dim(cube)[3], function(z) abind::adrop(cube[,,z,drop=FALSE], 3))
  names(vars) <- dimnames(cube)[[3]]

  return(vars)
}
