#' Expand a list of inputs using globbing
#'
#' Expand a list of inputs using globbing, returning
#' a single list of filenames.  The list of filenames
#' may contain duplicates.  If any supplied glob does
#' not match any existing files, this function will
#' cause the program to abort.
#'
#' @param raw_inputs a list of file path globs
#' @return a list of filenames
#' @export
expand_inputs <- function(raw_inputs) {
  inputs <- NULL;

  for (arg in raw_inputs) {
    globbed <- Sys.glob(arg)

    if (length(globbed) == 0) {
      die_with_message("No input files found matching pattern: ", arg)
    }
    inputs <- c(inputs, globbed)
  }

  return(inputs)
}
