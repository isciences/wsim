#' Read model forcing from a netCDF file
#'
#' @param fname netCDF file containing forcing data
#' @return \code{wsim.lsm.forcing} object containing model forcing
#'
#' @export
read_forcing_from_cdf <- function(fname) {
  contents <- wsim.io::read_vars_from_cdf(fname)

  args <- c(contents["extent"],
            contents$data[c("daylength", "pWetDays", "T", "Pr")])

  return(do.call(make_forcing, args))
}
