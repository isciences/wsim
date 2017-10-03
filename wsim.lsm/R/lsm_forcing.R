#' Make a WSIM LSM forcing
#'
#' @param extent spatial extent of input matrices \code{(xmin, xmax, ymin, ymax)}
#' @param T Temperature [degrees C]
#' @param Pr Precipitation [mm]
#' @param pWetDays Percentage of days in which precipitation falls [-]
#'
#' @return \code{wsim.lsm.forcing} object containing supplied variables
#' @export
make_forcing <- function(extent, pWetDays, T, Pr) {
  forcing <- list(
    pWetDays= pWetDays,
    T= T,
    Pr= Pr
  )

  if (!all(sapply(forcing, is.matrix)))
    stop('Non-matrix input in make_forcing')

  if (length(unique(lapply(forcing, dim))) > 1)
    stop('Unequal matrix dimensions in make_forcing')

  forcing$extent <- extent

  class(forcing) <- 'wsim.lsm.forcing'

  return(forcing)
}

#' Determine if an object represents an LSM forcing
#'
#' @param thing object to test
#' @export
is.wsim.lsm.forcing <- function(thing) {
  inherits(thing, 'wsim.lsm.forcing')
}
