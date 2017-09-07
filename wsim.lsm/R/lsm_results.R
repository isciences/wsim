#' Create a set of WSIM LSM results
#' @export
make_results <- function(
  Bt_RO,
  Bt_Runoff,
  E,
  EmPET,
  PET,
  PETmE,
  P_net,
  RO_m3,
  RO_mm,
  Runoff_m3,
  Runoff_mm,
  Sa,
  Sm,
  Ws_ave,
  dWdt,
  extent
) {

  results <- list(
    Bt_RO= Bt_RO,
    Bt_Runoff= Bt_Runoff,
    E= E,
    EmPET= EmPET,
    PET= PET,
    PETmE= PETmE,
    P_net= P_net,
    RO_m3= RO_m3,
    RO_mm= RO_mm,
    Runoff_m3= Runoff_m3,
    Runoff_mm= Runoff_mm,
    Sa= Sa,
    Sm= Sm,
    Ws_ave= Ws_ave,
    dWdt= dWdt
  )

  if (!all(sapply(results, is.matrix)))
    stop('Non-matrix input in make_results')

  if (length(unique(lapply(results, dim))) > 1)
    stop('Unequal matrix dimensions in make_results')

  results$extent <- extent

  class(results) <- "wsim.lsm.results"

  return(results)
}

#' Determine if an object represents LSM model results
#' @export
is.wsim.lsm.results <- function(thing) {
  inherits(thing, 'wsim.lsm.results')
}
