#' Change in soil moisture
#' @param P   Effective precipitation (mm/day)
#' @param E0  Potential evapotranspiration (mm/day)
#' @param Ws  Soil moisture (mm)
#' @param Wc  Soil moisture holding capacity (mm)
#' @return    Change in soil moisture (mm/day)
soil_moisture_change <- function(P, E0, Ws, Wc)  {
  Dws = (Wc - Ws) + E0  # soil moisture deficit
  
  if (P <= E0) {
    #cat("P <= E0", P, E0, Ws, Wc, "\n")
    # Precipitation is less than potential
    # evaporation, so we will experience
    # soil drying
    
    # TODO note that this does not match WSIM docs
    # but does appear to match Kepler
    # The docs would have us include the (E0 - P) term
    dWdt = -g(Ws, Wc, E0, P) #* (E0 - P)
    
    # Prevent extreme drying in a single timestep.
    # This is taken from the Kepler workspace, but does not
    # appear in the technical manual.
    # TODO update manual
    #return(dWdt) 
    return(max(dWdt, -0.9*Ws))
  } else if  (P <= Dws) {
    #cat("P <= DS\n")
    # Precipitation is exceeds the potential evapotranspiration
    # demand, but is less than the soil moisture deficit.
    # Any precipitation not consumed by potential evapotranspiration
    # will be absorbed by the soil.
    return (P - E0)
  } else {
    #cat("else\n")
    # Precipitation exceeds potential evapotranspiration and
    # the soil moisture deficit.  Fill the soil to capacity.
    return (Wc - Ws)
  }
}
