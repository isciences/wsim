#' Read multiple variables to a 3D array
#'
#' @param vardefs a list or vector of variable definitions
#'                as described in \code{\link{parse_vardef}}
#' @attrs_to_read a vector of global attribute names to be
#'                read from the first variable definition
#'                and attached as attributes to the returned
#'                array.
#' @return a 3D array.  The dimnames of the third dimension
#'         will contain the variable names of the inputs, and
#'        the extent will be attached as an attribute.
#' @export
read_vars_to_cube <- function(vardefs, attrs_to_read=as.character(c())) {
  vars <- lapply(vardefs, wsim.io::read_vars)
  extent <- vars[[1]]$extent

  for (var in vars) {
    if (!all(var$extent == extent)) {
      stop("Cannot create cube from layers with unequal extents.")
    }
  }

  data <- do.call(c, lapply(vars, `[[`, 'data'))

  cube <- abind::abind(data, along=3)
  attr(cube, 'extent') <- extent

  for (attr in attrs_to_read) {
    attr(cube, attr) <- vars[[1]]$attrs[[attr]]
  }

  return(cube)
}
