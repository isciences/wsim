#' Display a message and exit the program
#'
#' All arguments will be concatenated together.
#' Program will exit with status=1
#'
#' @param ... A list that will be concatenated into an
#'            error message
#' @export
die_with_message <- function(...) {
  fatal(list(...))
  if(interactive()) {
    stop()
  } else {
    quit(save='no', status=1, runLast=FALSE)
  }
}
