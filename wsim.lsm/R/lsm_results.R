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
  Pr,
  RO_m3,
  RO_mm,
  Runoff_m3,
  Runoff_mm,
  Sa,
  Sm,
  T,
  Ws,
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
    Pr=Pr,
    RO_m3= RO_m3,
    RO_mm= RO_mm,
    Runoff_m3= Runoff_m3,
    Runoff_mm= Runoff_mm,
    Sa= Sa,
    Sm= Sm,
    T= T,
    Ws= Ws,
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
