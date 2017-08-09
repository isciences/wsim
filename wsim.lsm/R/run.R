#' Run the model
#'
#' @param static a list containing static inputs to the model
#' @param state a list containing an input state for the model
#' @param forcing a list containing forcing data for the model
#' @return a list containing model outputs and a state for the next time step.
#' @export
run <- function(static, state, forcing) {
  obs <- list()
  next_state <- list()

  T <- raster::values(forcing$T)
  Pr <- raster::values(forcing$Pr)
  pWetDays <- raster::values(forcing$pWetDays)

  z <- raster::values(static$elevation)
  daylength <- raster::values(static$daylength)
  Wc <- raster::values(static$Wc)
  area_m2 <- raster::values(static$area_m2)

  snowpack <- raster::values(state$snowpack)
  Ws <- raster::values(state$Ws)
  Dr <- raster::values(state$Dr)
  Ds <- raster::values(state$Ds)

  melt_month <- ifelse(T > -1, raster::values(state$snowmelt_month) + 1, 0)

  # estimate snow accumulation and snowmelt
  Sa <- snow_accum(Pr, T)
  Sm <- snow_melt(snowpack, melt_month, T, z)

  P <- P_effective(Pr, Sa, Sm)

  E0 <- e_potential(daylength, T, forcing$nDays)

  dWdt <- vector(mode='numeric', length=length(P))
  E <- vector(mode='numeric', length=length(P))
  R <- vector(mode='numeric', length=length(P))
  dWdt[] <- NA
  E[] <- NA
  R[] <- NA

  print('Entering hydro loop.')
  all_defined <- !is.na(Pr) & !is.na(Sm) & !is.na(E0) & !is.na(Ws) & !is.na(Wc)
  for (i in 1:length(P)) {
    if (i %% 2592 == 0) {
      cat(i / 2592, '\n')
    }
    if (all_defined[i]) {
      hydro <- daily_hydro(P[i], Sm[i], E0[i], Ws[i], Wc[i], forcing$nDays, pWetDays[i])
      dWdt[i] <- hydro$dWdt
      E[i] <- hydro$E
      R[i] <- hydro$R
    }
  }

  Xr <- calc_Xr(R, Pr, P)
  Xs <- calc_Xs(Sm, R, P)

  Rp <- calc_Rp(Dr, Xr)
  Rs <- runoff_detained_snowpack(Ds, Xs, melt_month, z)

  revised_runoff <- Rp + Rs

  # Calculate changes in detention state variables
  dDrdt <- 0.5*(Dr + Xr)
  dDsdt = Xs - Rs

  make_raster <- function(vals) {
    r <- raster::raster(nrows=nrow(state$snowpack),
                ncol=ncol(state$snowpack))
    raster::values(r) <- vals
    raster::projection(r) <- raster::projection(state$snowpack)
    raster::extent(r) <- raster::extent(state$snowpack)
    r
  }

  next_state$snowpack <- make_raster(snowpack + Sa - Sm)
  next_state$snowmelt_month <- make_raster(melt_month)
  next_state$Ws <- make_raster(Ws + dWdt)
  next_state$Dr <- make_raster(Dr + dDrdt)
  next_state$Ds <- make_raster(Ds + dDsdt)

  obs$dayLength <- make_raster(daylength)
  obs$dWdt <- make_raster(dWdt)
  obs$E <- make_raster(E)
  obs$EmPET <- make_raster(E - E0)
  obs$P_net <- make_raster(P)
  obs$PET <- make_raster(E0)
  obs$PETmE <- make_raster(E0 - E)
  obs$Pr <- make_raster(Pr)
  obs$RO_mm <- make_raster(revised_runoff)
  obs$RO_m3 <- make_raster(revised_runoff*area_m2/1000)
  obs$Runoff_mm <- make_raster(R)
  obs$Runoff_m3 <- make_raster(R*area_m2/1000)
  obs$Sa <- make_raster(Sa)
  obs$Sm <- make_raster(Sm)
  obs$T <- make_raster(T)
  obs$Bt_RO <- make_raster(accumulate_flow(obs$RO_m3,  static$flow_directions))
  obs$Bt_Runoff <- make_raster(accumulate_flow(obs$Runoff_m3, static$flow_directions))

  return(list(obs=obs, next_state=next_state))
}
