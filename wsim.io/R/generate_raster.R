#' Generate a netCDF populated with data from a generator
#'
#' @param fname    of the generated netCDF
#' @param varnames character vector of variable names
#'                 to write to \code{fname}
#' @param generator a function that will be called with
#'                  no arguments to produce values to
#'                  populate the variables
#' @param nrow      number of rows in the generated
#'                  netCDF
#' @param ncol      number of columns in the generated
#'                  netCDF
#' @inheritParams write_vars_to_cdf
#'
#' @export
generate_raster <- function(fname, varnames=c("data"), generator=stats::runif, nrow=18, ncol=36, extent=c(-180, 180, -90, 90), attrs=list(), append=FALSE) {
  data <- lapply(varnames, function(x) {
    matrix(generator(nrow*ncol), nrow=nrow)
  })

  names(data) <- varnames

  write_vars_to_cdf(data,
                    fname,
                    extent=extent,
                    attrs=attrs,
                    append=append)
}
