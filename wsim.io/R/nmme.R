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


#' Read a variable from an NMME file as distributed by NOAA
#'
#' Data will be rotated from 0-360 to -180-180 and disaggregated to
#' a 0.5-degree global grid.
#'
#' @param fname path to netCDF file
#' @param var name of variable to read, e.g., 'fcst'
#' @param lead_months integer number of lead months, where zero
#'                    corresponds to the month when the forecast
#'                    was issued
#' @param member ensemble member for forecasts, starting with \code{1}
#' @return data
#' @examples
#' \dontrun{
#' oct_precip_anom <- read_nmme_noaa('/tmp/NASA_GEOS5v2.prate.201909.anom.nc', 'fcst', 1, 3)
#' oct_precip_clim <- read_nmme_noaa('/tmp/NASA_GEOS5v2.tmp2m.01.mon.clim.nc', 'clim', 1)
#' }
read_nmme_noaa <- function(fname, var, lead_months, member=NULL) {
  stopifnot(lead_months == as.integer(lead_months))

  nc <- ncdf4::nc_open(fname)

  s <- as.vector(ncdf4::ncvar_get(nc, 'initial_time'))

  ncdf4::nc_close(nc)

  extra_dims <- list(
    target = s + lead_months
  )
  if (!is.null(member)) {
    extra_dims$ensmem <- member
  }

  nmme <- read_vars(sprintf('%s::%s', fname, var), extra_dims=extra_dims)
  for (var in names(nmme$data)) {
    nmme$data[[var]] <- nmme_to_halfdeg(nmme$data[[var]])
  }
  nmme$extent <- c(-180, 180, -90, 90)

  return(nmme)
}

#' Compute NMME variable based on forecast and climatology
#'
#' @param fname_anom path to file containing anomalies
#' @param fname_clim path to file containing climatology
#' @param lead_months number of lead months in forecast
#' @param member ensemble member for forecast
#'
#' @return forecast values expressed in scientific units
#' @examples
#' \dontrun{
#' oct_precip <- read_nmme_fcst_noaa('/tmp/NASA_GEOS5v2.prate.201909.anom.nc',
#'                                   '/tmp/NASA_GEOS5v2.prate.09.mon.clim.nc', 1, 3)
#' }
read_nmme_fcst_noaa <- function(fname_anom, fname_clim, lead_months, member) {
  anom <- read_nmme_noaa(fname_anom, 'fcst', lead_months, member)
  clim <- read_nmme_noaa(fname_clim, 'clim', lead_months)

  anom$data$fcst <- clim$data$clim + anom$data$fcst
  return(anom)
}

#' Read from an NMME hindcast file distributed by IRIDL
#'
#' Data will be rotated from 0-360 to -180-180 and disaggregated to
#' a 0.5-degree global grid.
#'
#'
#' @param fname path to netCDF file
#' @param var name of forecast variable (e.g., \code{tref})
#' @param start_month month in which forecast was issues (1-12)
#' @param lead_months integer number of lead months, where zero
#'                    corresponds to the month when the forecast
#'                    was issued
#' @param members one or more ensemble members (1-indexed) to read,
#'                or \code{NULL} to read all ensemble members
#' @examples
#' \dontrun{
#'   oct_fcsts <- read_iri_hindcast('cancm4i_tref_hindcast.nc', 'tref', 9, 1)
#' }
read_iri_hindcast <- function(fname, var, start_month, lead_months, members=NULL) {
  stopifnot(start_month %in% 1:12)
  nc <- ncdf4::nc_open(fname)

  svals <- forecast_times_for_month(ncdf4::ncvar_get(nc, 'S'), start_month)

  if (is.null(members)) {
    members <- ncdf4::ncvar_get(nc, 'M')
  }

  ncdf4::nc_close(nc)

  v <- list()
  i <- 1
  for (member in members) {
    for (s in svals) {
      v[[i]] <- nmme_to_halfdeg(read_vars(sprintf('%s::%s', fname, var),
                  extra_dims=list(S=s, M=member, L=lead_months+0.5))$data[[1]])
      i <- i+1
    }
  }

  abind::abind(v, along=3)
}
