#' Expand a list of inputs using globbing and date range
#' expansion, returning a single list of filenames.
#'
#' Glob expansion is performed using a system call.
#'
#' Date range expansion is performed by including
#' a date range in square brackets, e.g. \code{results_[201201:201203].nc}, or
#' \code{results[195004:200904:12]}, where the third value
#' indicates the number of months between successive
#' dates in the range.
#'
#' The list of filenames may contain duplicates.
#'
#' If any supplied filename, date range, or glob does
#' not match an existing file, this function will
#' throw an error, unless \code{check_exists} is set to
#' \code{FALSE}.
#'
#' @param raw_inputs a list of file path globs
#' @param check_exists should we throw and error if
#'                     a specified file does not exist,
#'                     or if a glob returns no matches?
#' @return a list of filenames
#' @export
expand_inputs <- function(raw_inputs, check_exists=TRUE) {
  inputs <- NULL

  for (arg in raw_inputs) {
    splitarg <- strsplit(arg, '::', fixed=TRUE)[[1]]
    file_pattern <- splitarg[1]
    files <- c()

    # Expand date ranges
    for (pattern in expand_dates(file_pattern)) {
      expanded_glob <- Sys.glob(pattern)

      if (length(expanded_glob) > 0) {
        files <- c(files, expanded_glob)
      } else {
        if (check_exists) {
          stop("No input files found matching pattern: ", arg)
        } else {
          # Nothing picked up by Sys.glob, so consider
          # the pattern to be the filename
          files <- c(files, pattern)
        }
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

#' Expand any date ranges encoded in a filename
#'
#' @param fname file name or glob, possibly containing
#'              one or more date ranges between square
#'              brackets
#' @return a vector of filenames or globs
expand_dates <- function(fname) {
  match <- regexpr('\\[[0-9]+:[0-9]+(:[0-9]+)?\\]', fname)

  pos <- match[[1]]
  len <- attr(match, 'match.length')

  if (pos == -1) {
    return (fname)
  }

  range <- strsplit(substring(fname, pos + 1, pos + len - 2), ':', fixed=TRUE)[[1]]
  range_start <- range[1]
  range_stop  <- range[2]
  range_step  <- ifelse(length(range) > 2, as.integer(range[3]), 1)

  as.vector(sapply(date_range(range_start, range_stop, range_step),
         function(date) {
           paste0(substring(fname, 0, pos - 1), # everything before the match
                  date,
                  expand_dates(substring(fname, pos + len)))
         }, USE.NAMES=FALSE))
}

#' Expand a range of dates
#'
#' @param start start of range in YYYYMM format
#' @param stop  end of range in YYYYMM format
#' @param step  number of months between range
#'              elements.
#' @return a vector of dates in YYYYMM format
date_range <- function(start, stop, step) {
  dates <- c()
  while(start <= stop) {
    dates <- c(dates, start)
    start <- add_months(start, step)
  }
  return(dates)
}

#' Add a specificed number of months to a date
#'
#' @param yyyymm date in YYYYMM format
#' @param n      number of months to add to date
#' @return yyyymm + n
add_months <- function(yyyymm, n) {
  year <-  as.integer(substr(yyyymm, 1, 4))
  month <- as.integer(substr(yyyymm, 5, 6))


  month <- month + n

  while(month > 12) {
    month <- month - 12
    year  <- year + 1
  }

  return(sprintf('%04d%02d', year, month))
}
