#' @export
generate_raster <- function(fname, varnames=c("data"), generator=runif, nrow=18, ncol=36, extent=c(-180, 180, -90, 90), attrs=list(), append=FALSE) {
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
