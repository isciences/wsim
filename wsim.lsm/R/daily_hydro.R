daily_hydro <- function(Pr, Sm, E0, Ws, Wc, nDays, pWetDays) {
  PET_daily <- E0 / nDays
  
  dWdt <- 0
  E <- 0
  R <- 0
  
  Pr_daily <- make_daily_precip(Pr - Sm, nDays, pWetDays)
  Sm_daily <- make_daily_precip(Sm, nDays)
  
  #i <- 0
  for (P_daily in Pr_daily + Sm_daily) {
    #cat("R Day", i, ':', P_daily, '\n')
    #i <- i+1
    
    dWdt_daily <- soil_moisture_change(P_daily, PET_daily, Ws, Wc)
    #cat(dWdt_daily, '\n')
    #print(dWdt_daily)
    
    Ws <- Ws + dWdt_daily
    dWdt <- dWdt + dWdt_daily
    
    E_daily <- evapotranspiration(P_daily, PET_daily, dWdt_daily)
    E <- E + E_daily
    
    R_daily <- runoff(P_daily, E_daily, dWdt_daily)
    R <- R + R_daily
  }
  
  return(list(dWdt=dWdt, E=E, R=R))
}
