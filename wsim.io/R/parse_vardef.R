#' Parse a reference to a variable within a file
#'
#' @param vardef A variable definition, which may be of the following
#'               forms:
#' @return a list containing:
#' \describe{
#' \item{filename}{The filename containing the data}
#' \item{vars}{A list of variables within the file.  If NULL, then
#'             all variables within the file should be read.}
#' }
parse_vardef <- function(vardef) {
  # Parse a filename in the form of "mydata.cdf::var1,var2"
  # Add any vars found by this method to the list of vars
  split_fname <- strsplit(vardef, '::', fixed=TRUE)[[1]]
  fname <- split_fname[1]
  vars <- NULL
  if (length(split_fname) == 2) {
    vars <- c(vars, strsplit(split_fname[2], ',', fixed=TRUE)[[1]])
  }

  return(list(
    filename=fname,
    vars=vars
  ))
}
