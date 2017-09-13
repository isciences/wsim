#' Parse a reference to a variable within a file
#'
#' @param vardef A variable definition, constructed
#'               using the following syntax:
#'               <filename>::<variables_or_bands>
#'               where \code{<variables_or_bands> } is a comma-separated list
#'               of band numbers or variable names.
#'
#'               A limited amount of transformation can be specified by adding
#'               extra characters to the band number or variable name:
#'               \itemize{
#'               \item{Variables can be renamed by appending \code{->new_var_name}}
#'               \item{Data can be transformed by appending transformations such as
#'                     \code{@negate@fill0 }}
#'               }
#'
#'               A complete example is:
#'               \code{PETmE_freq_trgt201701.img::1@fill0@negate->Neg_PETmE}
#'
#'               In this example, band 1 is read from the file. NODATA values
#'               are replaced with zero, and all values are negated. The values
#'               are read into a variable called \code{Neg_PETmE}.
#'
#' @return a list containing:
#' \describe{
#' \item{filename}{The filename containing the data}
#' \item{vars}{A list of variables within the file.  If NULL, then
#'             all variables within the file should be read.}
#' }
#' @export
parse_vardef <- function(vardef) {
  # Parse a filename in the form of "mydata.cdf::var1,var2"
  # Add any vars found by this method to the list of vars
  split_fname <- strsplit(vardef, '::', fixed=TRUE)[[1]]
  fname <- split_fname[1]

  vars <- NULL
  if (length(split_fname) == 2) {
    vars <- lapply(strsplit(split_fname[2], ',', fixed=TRUE)[[1]], parse_var)
  }

  return(list(
    filename=fname,
    vars=vars
  ))
}

parse_var <- function(var) {
  split_1 <- strsplit(var,        '->', fixed=TRUE)[[1]]
  split_2 <- strsplit(split_1[1], '@',  fixed=TRUE)[[1]]

  var_in <- split_2[1]

  if (length(split_1) > 1)
    var_out <- split_1[2]
  else
    var_out <- var_in

  transforms <- split_2[-1]

  return(make_var(
    var_in= var_in,
    var_out= var_out,
    transforms= transforms
  ))
}

#' @export
make_var <- function(var_in, var_out=NULL, transforms=as.character(c())) {
  if (is.null(var_out)) {
    var_out <- var_in
  }

  var <- list(
    var_in= var_in,
    var_out= var_out,
    transforms= transforms
  )

  class(var) <- 'wsim.io.var'
  return(var)
}

#' @export
print.wsim.io.var <- function(v) {
  s <- v$var_in
  for (transform in v$transforms) {
    s <- paste0(s, '@', transform)
  }
  if (v$var_out != v$var_in) {
    s <- paste0(s, '->', v$var_out)
  }
  cat(s, '\n')
}
