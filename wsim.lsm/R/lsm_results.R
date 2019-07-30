# Copyright (c) 2018-2019 ISciences, LLC.
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

#' Create a set of WSIM LSM results
#'
#' @param Bt_RO accumulated total blue water runoff (taking account of detention) [m^3]
#' @param Bt_Runoff accumulated total blue water runoff (not taking account of detention) [m^3]
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
#' @param Ws average soil moisture [mm]
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
  Ws,
  dWdt,
  extent,
  digits_mm,
  digits_m3
) {
  stopifnot(!is.null(digits_mm) && !is.null(digits_m3))

  results <- list(
    Bt_RO= round(Bt_RO, digits_m3),
    Bt_Runoff= round(Bt_Runoff, digits_m3),
    E= round(E, digits_mm),
    EmPET= round(EmPET, digits_mm),
    PET= round(PET, digits_mm),
    PETmE= round(PETmE, digits_mm),
    P_net= round(P_net, digits_mm),
    RO_m3= round(RO_m3, digits_m3),
    RO_mm= round(RO_mm, digits_mm),
    Runoff_m3= round(Runoff_m3, digits_m3),
    Runoff_mm= round(Runoff_mm, digits_mm),
    Sa= round(Sa, digits_mm),
    Sm= round(Sm, digits_mm),
    Ws= round(Ws, digits_mm),
    dWdt= round(dWdt, digits_mm)
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
