#' Read model forcing from a netCDF file
#'
#' @param fname netCDF file containing forcing data
#' @return \code{wsim.lsm.forcing} object containing model forcing
#'
#' @export
read_forcing_from_cdf <- function(fname) {
  contents <- wsim.io::read_vars_from_cdf(fname)

  args <- c(contents["extent"],
            contents$data[c("pWetDays", "T", "Pr")])
  
  # TODO use udunits2 package to pick out synonyms, or
  # perform automatic conversions?
  wsim.io::check_units(contents, 'T',  'degree_Celsius', fname)
  wsim.io::check_units(contents, 'Pr', 'mm', fname)
  
  return(do.call(make_forcing, args))
}

