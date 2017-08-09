make_daily_precip <- function(P_monthly, nDays, pWetDays=NULL) {
  if (is.null(pWetDays) || pWetDays == 1.0) {
    # Monthly precip is evenly distributed among all days
    return(rep.int(P_monthly / nDays, nDays))
  } else {
    # Monthly precip is evenly distributed among an evenly-spaced
    # set of rainy days
    
    # Set a floor of 3.2% wet days.  Taken from Kepler workflow.
    pWetDays <- max(pWetDays, 0.032)
    
    wetDays <- makeWetDayList(nDays, pWetDays)
    
    #cat('R wet days', wetDays, '\n') 
    
    precip <- rep.int(0.0, nDays)
    precip[wetDays] = P_monthly / length(wetDays)
    return(precip)
  }
}