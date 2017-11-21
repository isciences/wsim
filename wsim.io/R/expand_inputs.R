#' Expand a list of inputs using globbing
#'
#' Expand a list of inputs using globbing, returning
#' a single list of filenames.  The list of filenames
#' may contain duplicates.  If any supplied glob does
#' not match any existing files, this function will
#' cause the program to abort.
#'
#' @param raw_inputs a list of file path globs
#' @param expand_globs should we try to expand inputs
#'                     as filepath globs?
#' @param check_exists should we abort the program if
#'                     a specified file does not exist,
#'                     or if a glob returns no matches?
#' @return a list of filenames
#' @export
expand_inputs <- function(raw_inputs, expand_globs=TRUE, check_exists=TRUE) {
  inputs <- NULL;

  for (arg in raw_inputs) {
    splitarg <- strsplit(arg, '::', fixed=TRUE)[[1]]
    pattern <- splitarg[1]

    if (expand_globs) {
      files <- Sys.glob(pattern)

      if (check_exists && length(files) == 0) {
        die_with_message("No input files found matching pattern: ", arg)
      }
    } else {
      files <- c(pattern)

      if (check_exists && !file.exists(pattern)) {
        die_with_message("File does not exist: ", pattern)
      }
    }

    # Add variable list back on to each expanded filename
    if (length(splitarg) > 1) {
      files <- sapply(files, function(fname) {
        paste0(fname, '::', splitarg[2])
      })
    }

    inputs <- c(inputs, files)
  }

  return(inputs)
}
