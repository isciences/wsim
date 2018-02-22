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
