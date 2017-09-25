#' Get the next month
#'
#' @param yyyymm Year/month in YYYYMM format
#' @return Following month in YYYYMM format
#' @export
next_yyyymm <- function(yyyymm) {
  first_day_of_current_month <- as.Date(paste0(yyyymm, '01'), '%Y%m%d')
  next_ymm <- strftime(first_day_of_current_month + 31, '%Y%m')

  leading_zeros <- paste(rep('0', nchar('YYYYMM') - nchar(next_ymm)), collapse='')
  return(paste0(leading_zeros, next_ymm))
}
