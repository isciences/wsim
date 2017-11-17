#' Check the units of data read by \code{read_vars_from_cdf}
#' 
#' If the units are undefined, a warning will be issued.
#' If the units are incorrect, a the program will exit.
#' 
#' @param data           object returned by \code{read_vars_from_cdf}
#' @param var            name of variable to check
#' @param expected_units expected units of variable (e.g., 'mm')
#' @param fname          filename from which variable was read (used for
#'                       creating an error message only)
#' @return nothing
#' @export
check_units <- function(data, var, expected_units, fname) {
  units <- attr(data$data[[var]], 'units') 
  
  if (is.null(units)) {
    warn("Undefined units for variable", var, "in", fname, ".")
  } else if (units != expected_units) {
    die_with_message("Unexpected units for variable", var, "in", fname,
                     "( expected", expected_units, "got", units, ")")
  }

}