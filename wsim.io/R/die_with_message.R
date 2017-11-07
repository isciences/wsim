#' Display a message and exit the program
#'
#' All arguments will be concatenated together.
#' Program will exit with status=1
#'
#' @param ... A list that will be concatenated into an
#'            error message
#' @export
die_with_message <- function(...) {
  args <- list(...)
  if (length(args) == 1 && inherits(args[[1]], "error")) {
    fatal(args[[1]]$message)
  } else {
    fatal(...)
  }

  if(interactive()) {
    stop("Fatal error encountered in interactive session.")
  } else {
    quit(save='no', status=1, runLast=FALSE)
  }
}
