#' Read a raster filename, extract a date in yyyymm format if it's contained in the filename, and return the number of days in the month mm.
#' Note that this does not take leap years into account, i.e. 28 is always returned for month 02.
#'
#' This is because WSIM uses on monthly sums and averages as the lowest temporal unit of its variables,
#' and we determine, e.g., monthly precipitation, by aggregating an average rate up by the number of days in the month.
#' If we were to compare precipitation between a 29-day February and a series of 28-day Februaries,
#' the 29-day February may look anomalous merely by comprising one more day of average rainfall than the other Februaries.
#'
#' @param raster_fname A character string representing a filename.
#' @return An integer of the number of days in the month component of the extracted yyyymm
#' examples
#' get_ndays_from_fname('~/Documents/wsim/source/GLDAS_NOAH025_M.A194801.020.nc4')
get_ndays_from_fname <- function(raster_fname){
  # searches for year in 19** - 20**, month in 01-19:
  fname_regex <- gregexpr('[1,2]{1}[9,0]{1}[0-9]{2}[0-1]{1}[0-9]{1}', raster_fname)
  if(length(fname_regex[[1]]) > 1){
    stop('Multiple dates found in filename: ', raster_fname )
  }
  else if(fname_regex[[1]][[1]] == -1){
    stop("No dates found in filename: ", raster_fname)
  }
  yyyymm       <- substr(raster_fname,
                         start = fname_regex[[1]][[1]],
                         stop = fname_regex[[1]][[1]] + attributes(fname_regex[[1]])$match.length - 1)
  ndays_in_month <- wsim.lsm::days_in_yyyymm(yyyymm)

  # Override if leap year:
  if(ndays_in_month == 29 & substr(yyyymm, 5, 6) == '02'){
    ndays_in_month <- 28
  }

  return(ndays_in_month)
}
