# Copyright (c) 2018-2021 ISciences, LLC.
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

#' Read model forcing from a netCDF file
#'
#' @param fname netCDF file containing forcing data
#' @param yearmon year and month associated with the forcing, in YYYYMM format
#' @return \code{wsim.lsm.forcing} object containing model forcing
#'
#' @export
read_forcing_from_cdf <- function(fname, yearmon) {
  contents <- wsim.io::read_vars_from_cdf(fname)

  temp_units <- attr(contents$data$T, 'units')
  if (temp_units != 'degree_Celsius') {
    contents$data$T <- temp_celsius(contents$data$T, temp_units)
    attr(contents$data$T, 'units') <- 'degree_Celsius'
  }

  precip_units <- attr(contents$data$Pr, 'units')
  if (precip_units != 'mm') {
    contents$data$Pr <- precip_mm(contents$data$Pr, precip_units, days_in_yyyymm(yearmon), 'day')
    attr(contents$data$Pr, 'units') <- 'mm'
  }

  check_value_range(contents$data, 'pWetDays', 0, 1)
  check_value_range(contents$data, 'T', -80, 80) # GHCN+CAMS has values between -55 and +63 degrees C
  check_value_range(contents$data, 'Pr', 0, 5000) # PREC/L max is 3059 mm

  args <- c(contents["extent"],
            contents$data[c("pWetDays", "T", "Pr")])

  return(do.call(make_forcing, args))
}

check_value_range <- function(m, var, allowed_min, allowed_max) {
  x <- m[[var]]

  too_low <- which(x < allowed_min)
  if (length(too_low) > 0) {
    stop(sprintf('%d %s values below allowable minimum of %f', length(too_low), var, allowed_min))
  }

  too_high <- which(x > allowed_max)
  if (length(too_high) > 0) {
    stop(sprintf('%d %s values above allowable maximum of %f', length(too_high), var, allowed_max))
  }
}

#' Convert temperature to degrees Celsius
#'
#' @param x temperature value
#' @param u units of \code{x}
#' @return temperature value in degrees Celsius
temp_celsius <- function(x, u) {
  units::drop_units(units::set_units(units::set_units(x, u, mode='standard'), 'degree_C'))
}

#' Convert precipitation value to millimeters
#'
#' @param precip precipitation values
#' @param precip_units units of \code{precip}
#' @param duration an optional duration over which precipitation falls
#' @param duration_units units of \code{duration}
#' @return precipitation amount in millimeters
precip_mm <- function(precip, precip_units, duration, duration_units) {
  water_density <- units::set_units(1000, 'kg/m^3')

  precip <- units::set_units(precip, precip_units, mode='standard')

  # easiest case: we were given precipitation as [L]
  try(return(units::drop_units(units::set_units(precip, 'mm'))), silent=TRUE)

  if (!is.null(duration)) {
    duration <- units::set_units(duration, duration_units, mode='standard')

    # or maybe we were given a precipitation rate [L/T]
    try(return(units::drop_units(units::set_units(precip * duration, 'mm'))), silent=TRUE)

    # or maybe we were given a mass-based precipitation rate [M/L^2/T]
    try(return(units::drop_units(units::set_units(precip / water_density * duration, 'mm'))), silent=TRUE)
  }

  stop(sprintf('Cannot process precipitation data with units of %s', precip_units))
}
