# Copyright (c) 2018 ISciences, LLC.
# All rights reserved.
#
# WSIM is licensed under the Apache License, Version 2.0 (the "License").
# You may not use this file except in compliance with the License. You may
# obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0.
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

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
