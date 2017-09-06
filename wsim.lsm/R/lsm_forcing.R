#' Make a WSIM LSM forcing
#' @export
make_forcing <- function(extent, daylength, pWetDays, T, Pr) {
  forcing <- list(
    daylength= daylength,
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
#' @export
is.wsim.lsm.forcing <- function(thing) {
  inherits(thing, 'wsim.lsm.forcing')
}
