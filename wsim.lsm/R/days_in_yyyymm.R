#' Return the number of days in a given month
#'
#' @param yyyymm Year/month in YYYYMM format
#' @return number of days in month
#' @export
days_in_yyyymm <- function(yyyymm) {
  first_day <- as.Date(paste0(yyyymm, '01'), '%Y%m%d')
  return(unname(lubridate::days_in_month(first_day)))
}
