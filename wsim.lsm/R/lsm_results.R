#' Create a set of WSIM LSM results
#'
#' @param Bt_RO accumulated total blue water runoff (taking account of detention) [mm]
#' @param Bt_Runoff accumulated total blue water runoff (not taking account of detention) [mm]
#' @param E evapotranspiration [mm]
#' @param EmPET actual minus potential evapotranspiration [mm]
#' @param PET potential evapotranspiration [mm]
#' @param PETmE potential minus actual evapotranspiration [mm]
#' @param P_net net precipitation [mm]
#' @param RO_m3 runoff (taking account of detention) [m^3]
#' @param RO_mm runoff (taking account of detention) [mm]
#' @param Runoff_m3 runoff (not taking account of detention) [m^3]
#' @param Runoff_mm runoff (not taking account of detention) [mm]
#' @param Sa snow accumulation [mm]
#' @param Sm snowmelt [mm]
#' @param Ws_ave average soil moisture [mm]
#' @param dWdt change in soil moisture [mm]
#' @param extent spatial extent of input matrices \code{(xmin, xmax, ymin, ymax)}
#'
#' @return \code{wsim.lsm.results} object containing supplied variables
#'
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
#'
#' @param thing object to test
#' @export
is.wsim.lsm.results <- function(thing) {
  inherits(thing, 'wsim.lsm.results')
}
