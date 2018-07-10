#' Parse a statistic provided as a command-line argument
#'
#' Parses a statistic argument of the form
#' \code{stat}
#' or
#' \code{stat::var1,var2,var3}
#'
#' @param stat the argument string
#' @return a parsed \code{wsim.io.stat}
#' @export
parse_stat <- function(stat) {
  split_stat <- strsplit(stat, '::', fixed=TRUE)[[1]]

  if (length(split_stat) == 1) {
    return(make_stat(split_stat[1], as.character(c())))
  }

  vars_for_stat <- strsplit(split_stat[2], ',', fixed=TRUE)[[1]]
  return(make_stat(split_stat[1], vars_for_stat))
}

make_stat <- function(stat=NULL, vars=NULL) {
  structure(
    list(stat=stat, vars=vars),
    class='wsim.io.stat'
  )
}
