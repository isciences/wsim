#' Run the model using matrices
#'
#' @param static a list containing static inputs to the model
#' @param state a list containing an input state for the model
#' @param forcing a list containing forcing data for the model
#' @return a list containing model outputs and a state for the next time step.
#' @useDynLib wsim.lsm, .registration=TRUE
#' @export
run <- function(static, state, forcing) {
  melt_month <- ifelse(
    forcing$T > -1,
    state$snowmelt_month + 1,
    0
  )

  # estimate snow accumulation and snowmelt
  Sa <- snow_accum(forcing$Pr, forcing$T)
  Sm <- snow_melt(state$Snowpack, melt_month, forcing$T, static$elevation)

  P <- P_effective(forcing$Pr, Sa, Sm)

  E0 <- e_potential(forcing$daylength, forcing$T, forcing$nDays)

  hydro <- daily_hydro_loop(P, Sm, E0, state$Ws, static$Wc, forcing$nDays, forcing$pWetDays)
  dWdt <- matrix(hydro$dWdt, nrow=nrow(forcing$T), ncol=ncol(forcing$T))
  E <- matrix(hydro$E, nrow=nrow(forcing$T), ncol=ncol(forcing$T))
  R <- matrix(hydro$R, nrow=nrow(forcing$T), ncol=ncol(forcing$T))

  Xr <- calc_Xr(R, forcing$Pr, P)
  Xs <- calc_Xs(Sm, R, P)

  Rp <- calc_Rp(state$Dr, Xr)
  Rs <- runoff_detained_snowpack(state$Ds, Xs, melt_month, static$elevation)

  revised_runoff <- Rp + Rs

  # Calculate changes in detention state variables
  dDrdt <- 0.5*(state$Dr + Xr)
  dDsdt = Xs - Rs

  next_state <- list(
    Snowpack= state$Snowpack + Sa - Sm,
    snowmelt_month= melt_month,
    Ws= state$Ws + dWdt,
    Dr= state$Dr + dDrdt,
    Ds= state$Ds + dDsdt
  )

  obs <- list(
    dayLength= forcing$daylength,
    dWdt= dWdt,
    E= E,
    EmPET= E - E0,
    P_net= P,
    PET= E0,
    PETmE= E0 - E,
    Pr= forcing$Pr,
    RO_mm= revised_runoff,
    RO_m3= revised_runoff*static$area_m2/1000,
    Runoff_mm= R,
    Runoff_m3= R*static$area_m2/1000,
    Sa= Sa,
    Sm= Sm,
    T= forcing$T
  )
  obs$Bt_RO <- accumulate_flow(obs$RO_m3,  static$flow_directions)
  obs$Bt_Runoff <- accumulate_flow(obs$Runoff_m3, static$flow_directions)

  return(list(
    obs=obs,
    next_state=next_state
  ))
}
