#' Parse command-line arguments from a docopt string
#'
#' If specified arguments are not valid, this function will
#' print the usage information and exit the program with
#' status=1.
#'
#' @param usage a docopt string describing program usage
#' @return a list of parsed arguments
#'
#' @export
parse_args <- function(usage) {
  tryCatch(docopt::docopt(usage), error=function(e) {
    write('Error parsing args.', stderr())
    write(usage, stdout())
    quit(status=1)
  })
}