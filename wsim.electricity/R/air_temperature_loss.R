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

#' Estimate water temperature from air temperature
#' 
#' @param Twater water temperature [degrees C]
#' @return estimated air temperature [degrees C]
#' @export
water2air <- function(Twater) {
  (Twater - 2.5) / 0.76
}

#' Estimate air temperature from ater temperature
#' 
#' @param Tair air temperature [degrees C]
#' @return estimated ater temperature [degrees C]
#' @export
air2water <- function(Tair) {
  2.5 + Tair*0.76
}

eff_loss <- function() {
  # original implementation has complex logic that seems to result in
  # this being either 0.005 or 0.007
  0.005  
}

#' Temperature loss
#' 
#' @param To     air temperature at
#' @param To_rp  air temperature as a return period (yr). Negative values
#'               indicate cold anomalies; positive values indicate warm
#'               anomalies.
#' @param Tc     optional air temperature at which cold losses begin
#' @param Tc_rp  return period at which cold losses begin
#' @param Teff   optional water temperature at which efficiency loss begins
#' @param eff    efficiency loss per degree C above Teff
#' @param Treg   optional regulatory limit water temperature
#' @param Tdiff  effluent - influent water temperature
#' @export
temperature_loss <- function(To, To_rp, Tc=NULL, Tc_rp, Teff=NULL, eff, Treg=NULL, Tdiff) {
  loss_per_deg <- 1/30   
  
  # TODO vectorize?
  
  if (!is.null(Tc) && To <= Tc && To_rp < Tc_rp) {
    # Affected by cold
    cold_loss <- pmax(0, pmin(1, (Tc - To)*loss_per_deg))
  } else {
    cold_loss <- 0
  }
  
  if (!is.null(Treg) && To >= water2air(Treg - Tdiff))  {
    # Affected by effluent temperature regulations
    effluent_temperature_loss <- pmax(0, pmin(1, (air2water(To) - (Treg - Tdiff)) / Tdiff))
  } else {
    effluent_temperature_loss <- 0
  }
  
  if (!is.null(Teff) && To >= water2air(Teff)) {
    # Efficiency loss
    efficiency_loss <- pmax(0, pmin(1, eff * (To - water2air(Teff))))
  } else {
    efficiency_loss <- 0
  }
  
  pmax(cold_loss, efficiency_loss, effluent_temperature_loss)
}
