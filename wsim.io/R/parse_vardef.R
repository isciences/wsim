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
  if (is.wsim.io.vardef(vardef)) {
    return(vardef)
  }

  # Parse a filename in the form of "mydata.cdf::var1,var2"
  # Add any vars found by this method to the list of vars
  split_fname <- strsplit(vardef, '::', fixed=TRUE)[[1]]
  fname <- split_fname[1]

  vars <- list()
  if (length(split_fname) == 2) {
    vars <- lapply(strsplit(split_fname[2], ',', fixed=TRUE)[[1]], parse_var)
  }

  make_vardef(filename=fname, vars=vars)
}

#' Create a \code{wsim.io.vardef}
#'
#' A \code{wsim.io.vardef} is a reference to a file
#' from which one or more variables can be read.
#'
#' @param filename filename of vardef
#' @param vars     list of \code{wsim.io.var}
#'
#' @return a constructed \code{wsim.io.vardef}
#' @export
make_vardef <- function(filename, vars) {
  def <- list(
    filename= filename,
    vars= vars
  )

  class(def) <- 'wsim.io.vardef'

  return(def)
}

#' Check if an object is a \code{wsim.io.vardef}
#'
#' @param v a thing to test
#'
#' @return true if \code{v} is a \code{wsim.io.vardef}
#' @export
is.wsim.io.vardef <- function(v) {
  class(v) == 'wsim.io.vardef'
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

#' Create a \code{wsim.io.var}
#'
#' A \code{wsim.io.var} is a reference to a variable
#' to which zero or more transformations may be applied,
#' and whose name may be changed.
#'
#' @param var_in     name of the variable to read
#' @param var_out    optional name to which the variable
#'                   should be changed. If left as the default
#'                   NULL, \code{var_out} will be the same as
#'                   \code{var_in}.
#' @param transforms a character vector containing zero or
#'                   more text representations of transformations
#'                   to be applied to \code{var_in} after it is read.
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

#' Check if an object is a \code{wsim.io.var}
#'
#' @param v a thing to test
#'
#' @return true if \code{v} is a \code{wsim.io.var}
#' @export
#' @export
is.wsim.io.var <- function(v) {
  class(v) == 'wsim.io.var'
}

#' @method print wsim.io.var
#' @export
print.wsim.io.var <- function(x, ...) {
  cat(toString(x), '\n')
}

#' @method toString wsim.io.var
#' @export
toString.wsim.io.var <- function(x, ...) {
  s <- x$var_in
  for (transform in x$transforms) {
    s <- paste0(s, '@', transform)
  }
  if (x$var_out != x$var_in) {
    s <- paste0(s, '->', x$var_out)
  }

  s
}
