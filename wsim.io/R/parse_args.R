#' Parse command-line arguments from a docopt string
#'
#' If specified arguments are not valid, this function will
#' print the usage information and exit the program with
#' status=1.
#'
#' @param usage a docopt string describing program usage
#' @param args a list of command-line arguments
#' @param type an optional list of types to which specific
#'             arguments should be coerced, e.g. \code{list(num_cores="integer")}
#' @return a list of parsed arguments
#'
#' @export
parse_args <- function(usage, args=commandArgs(TRUE), types=list()) {
  parsed <- tryCatch(docopt::docopt(usage, args), error=function(e) {
    write('Error parsing args.', stderr())
    write(usage, stdout())
    if (interactive()) {
      stop()
    } else {
      quit(status=1)
    }
  })

  for (arg in names(parsed)) {
    if (!is.null(parsed[[arg]])) {
      typ <- types[[arg]]
      if (!is.null(typ)) {
        if (typ == 'integer') {
          parsed[[arg]] <- as.integer(parsed[[arg]])
        } else if (typ == 'double') {
          parsed[[arg]] <- as.double(parsed[[arg]])
        } else {
          stop('Unknown data type')
        }
      }
    }
  }

  return(parsed)
}
