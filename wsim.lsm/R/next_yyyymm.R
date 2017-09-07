#' Get the next month
#'
#' @param yyyymmm Year/month in YYYYMM format
#' @return Following month in YYYYMM format
#' @export
next_yyyymm <- function(yyyymm) {
  first_day_of_current_month <- as.Date(paste0(yyyymm, '01'), '%Y%m%d')
  return(strftime(first_day_of_current_month + 31, '%Y%m'))
}
