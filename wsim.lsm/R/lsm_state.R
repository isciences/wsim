#' Create a WSIM LSM state
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
#' @export
is.wsim.lsm.state <- function(thing) {
  inherits(thing, 'wsim.lsm.state')
}
