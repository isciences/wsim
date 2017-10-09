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
    return(function(x) { wsim_quantile(x, 0.5) })

  if (name == 'max')
    return(function(x) { unless_all_na(max)(x, na.rm=TRUE) })

  if (name == 'sum')
    return(function(x) { sum(x, na.rm=TRUE) })

  if (name == 'ave')
    return(function(x) { unless_all_na(mean)(x, na.rm=TRUE) })

  if (name == 'fraction_defined')
    return(function(x) { sum(!is.na(x)) / length(x) })

  if (name == 'fraction_defined_above_zero')
    return(function(x) { sum(x>0, na.rm=TRUE) / sum(!is.na(x)) })

  if (grepl('q\\d{1,2}(.\\d+)?$', name)) {
    q <- 0.01 * as.numeric(substring(name, 2))
    return(function(x) { wsim_quantile(x, q) })
  }

  stop("Unknown stat ", name)
}

unless_all_na <- function(fn) {
  function(x, ...) ifelse(all(is.na(x)), as.numeric(NA), fn(x, ...) )
}
