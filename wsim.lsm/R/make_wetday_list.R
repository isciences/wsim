makeWetDayList <- function(nDays, pWetDays) {
  WetDays <- round(pWetDays * nDays)
  
  if (WetDays == nDays) {
    return(1:nDays)
  }
  
  wetDayList <- NULL
  interval <- nDays / (WetDays+1)
  firstDay = 1 + as.integer(interval/2)
  day <- firstDay
  while(day <= (nDays-interval)) {
    day <- day + interval
    wetDayList <- c(wetDayList, as.integer(day))
  }
  
  return (wetDayList)
}