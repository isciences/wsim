#' Create a WSIM LSM state
#'
#' @param extent spatial extent of input matrices \code{(xmin, xmax, ymin, ymax)}
#' @param Snowpack snowpack water equivalent [mm]
#' @param Dr detained runoff [mm]
#' @param Ds detained snowmelt [mm]
#' @param Ws soil moisture [mm]
#' @param snowmelt_month number of months of consecutive melting conditions
#' @param yearmon year and month of state (state should represent MM/01/YYYY)
#'
#' @return \code{wsim.lsm.state} object containing supplied variables
#' @export
make_state <- function(extent, Snowpack, Dr, Ds, Ws, snowmelt_month, yearmon) {

  matrices <- list(
    Snowpack= Snowpack,
    Dr= Dr,
    Ds= Ds,
    Ws= Ws,
    snowmelt_month= snowmelt_month
  )

  attrs <- list(
    extent= extent,
    yearmon= yearmon
  )

  if (!all(sapply(matrices, is.matrix)))
    stop('Non-matrix input in make_state')

  if (length(unique(lapply(matrices, dim))) > 1)
    stop('Unequal matrix dimensions in make_state')

  if (!(is.character(yearmon) && nchar(yearmon)==6))
    stop('Invalid year-month in make_state')

  state <- c(matrices, attrs)
  class(state) <- 'wsim.lsm.state'

  return(state)
}

#' Determine if an object represents an LSM state
#'
#' @param thing object to test
#' @export
is.wsim.lsm.state <- function(thing) {
  inherits(thing, 'wsim.lsm.state')
}
