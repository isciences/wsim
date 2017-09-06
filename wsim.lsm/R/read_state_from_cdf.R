#' Read a model state from a netCDF file
#'
#' @param fname
#' @return
#' @export
read_state_from_cdf <- function(fname) {
  contents <- wsim.io::read_vars_from_cdf(fname)

  args <- c(contents$attrs["yearmon"],
            contents$data[c("Snowpack", "snowmelt_month", "Ws", "Dr", "Ds")])

  return(do.call(make_state, args))
}
