# Copyright (c) 2019 ISciences, LLC.
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

#' Convert a YYYYMM to months since January 1960
#' @param yearmon year/month in YYYYMM format
#' @return number of months since January 1960
months_since_jan_1960 <- function(yearmon) {
  stopifnot(is.character(yearmon))
  stopifnot(nchar(yearmon) == 6)

  year <- as.integer(substr(yearmon, 1, 4))
  month <- as.integer(substr(yearmon, 5, 6))

  years <- year - 1960

  12*years + month - 1
}

#' Convert months since January 1960 to YYYYMM
#'
#' @param s number of months since January 1960
#' @return year and month in YYYYMM format
yearmon_from_months_since_jan_1960 <- function(s) {
  stopifnot(!is.null(s))
  stopifnot(as.integer(s) == s)

  sprintf('%04d%02d',
          1960 + (s %/% 12),
          1 + (s %% 12))
}

#' Compute the number of lead months between a forecast reference time
#' and a target month
#'
#' @param reftime the YYYYMM when the forecast was generated
#' @param target the YYYYMM targeted by the forecast
#' @return the number of lead months (value of the \code{L} dimension)
lead_months <- function(reftime, target) {
  stopifnot(is.character(reftime))
  stopifnot(nchar(reftime) == 6)
  stopifnot(is.character(target))
  stopifnot(nchar(target) == 6)
  stopifnot(reftime <= target)

  0.5 + months_since_jan_1960(target) - months_since_jan_1960(reftime)
}

#' Return forecast reference times in a particular calendar month
#'
#' @param svals vector of months since January 1920
#' @param month calendar month from 1 to 12
#' @return subset of \code{svals}
forecast_times_for_month <- function(svals, month) {
  svals[1 + svals %% 12 == month]
}

#' Disaggregate a matrix from NMME grid to 0.5-degree global grid
#'
#' @param m a 181x360 matrix of values from an NMME forecast or climatology.
#'          The values must have been read using \code{\link{read_vars}} so
#'          that the longitude grid originating at -0.5 W has been wrapped to
#'          begin at -179.5 W.
nmme_to_halfdeg <- function(m) {
  stopifnot(dim(m) == c(181, 360))

  # The top and bottom rows of the NMME grid represent 0.5 degrees of latitude,
  # while the intermediate rows represent 1.0 degrees of latitude. To get to a
  # global 0.5-degree grid, we disaggregate the intemediate grid cells by a
  # factor of two but leave the top and bottom rows alone.
  lats <- c(1, rep(2:180, each=2), 181)

  # Per communication from IRI, longitude values represent grid centers, although
  # they are centered on even degrees of longitude instead of half-degrees of
  # longitude. This means that first column covers -179.5 to -178.5, and the
  # last column covers 179.5 to -179.5. When disaggregating to a half-degree
  # grid, we need to pull the values from the last column and put them in the first
  # column.
  lons <- c(360, rep(1:359, each=2), 360)

  m[lats, lons]
}

