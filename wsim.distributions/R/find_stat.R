#' Get a function to compute a named statistic over a vector of observations
#'
#' @param stat name of statistic. Supported statistics are:
#' \describe{
#' \item{min}{minimum defined value}
#' \item{max}{maximum defined value}
#' \item{ave}{mean defined value}
#' \item{median}{median defined value}
#' \item{qXX}{quantile \code{XX} of defined values}
#' }
#' @export
find_stat <- function(name) {
  name <- tolower(name)

  if (name == 'min')
    return(function(x) { unless_all_na(min)(x, na.rm=TRUE) })

  if (name == 'median')
    return(function(x) { unless_all_na(median)(x, na.rm=TRUE )})

  if (name == 'max')
    return(function(x) { unless_all_na(max)(x, na.rm=TRUE) })

  if (name == 'sum')
    return(function(x) { sum(x, na.rm=TRUE) })

  if (name == 'ave')
    return(function(x) { unless_all_na(mean)(x, na.rm=TRUE) })

  if (grepl('q\\d{1,2}(.\\d+)?$', name)) {
    q <- 0.01 * as.numeric(substring(name, 2))
    return(function(x) { unname(quantile(x, q, na.rm=TRUE)) })
  }

  stop("Unknown stat ", name)
}

unless_all_na <- function(fn) {
  function(x, ...) ifelse(all(is.na(x)), as.numeric(NA), fn(x, ...) )
}
