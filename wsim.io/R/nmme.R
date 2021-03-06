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

#' Disaggregate a matrix or array from NMME grid to 0.5-degree global grid
#'
#' @param m a 181x360xN array of values from an NMME forecast or climatology.
#'          The values must have been read using \code{\link{read_vars}} so
#'          that the longitude grid originating at -0.5 W has been wrapped to
#'          begin at -179.5 W.
#' @return a 360x720XN array of transformed values
#' @export
nmme_to_halfdeg <- function(m) {
  stopifnot(dim(m)[1:2] == c(181, 360))

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

  if (length(dim(m)) == 2) {
    m[lats, lons]
  } else if (length(dim(m)) == 3) {
    m[lats, lons, , drop=FALSE]
  } else {
    stop("Unhandled array size")
  }
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
#' @export
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

#' Read from an NMME hindcast file distributed by IRIDL
#'
#' @param fname path to netCDF file
#' @param var name of forecast variable (e.g., \code{tref})
#' @param target_month month targeted by forecast (1-12)
#' @param lead_months integer number of lead months, where zero
#'                    corresponds to the month when the forecast
#'                    was issued
#' @param min_target_year only read hindcasts with a target date
#'                        greater than or equal to specified year
#' @param max_target_year only read hindcasts with a target date
#'                        less than or equal to specified year
#' @param members one or more ensemble members (1-indexed) to read,
#'                or \code{NULL} to read all ensemble members
#' @param progress if \code{TRUE}, show a progress bar during reading
#' @return a 181x360xN array with the values from \code{N} hindcasts
#' @examples
#' \dontrun{
#'   oct_fcsts <- read_iri_hindcast('cancm4i_tref_hindcast.nc', 'tref', 9, 1)
#' }
#' @export
read_iri_hindcast <- function(fname, var, target_month, lead_months, min_target_year=NULL, max_target_year=NULL, members=NULL, progress=FALSE) {
  stopifnot(target_month %in% 1:12)
  stopifnot(lead_months == as.integer(lead_months))

  nc <- ncdf4::nc_open(fname)

  start_month <- target_month - lead_months
  if (start_month < 1) {
    start_month <- start_month + 12
  }

  svals <- forecast_times_for_month(ncdf4::ncvar_get(nc, 'S'), start_month)

  if (!is.null(min_target_year)) {
    target_years <- as.integer(substr(yearmon_from_months_since_jan_1960(svals + lead_months), 1, 4))
    svals <- svals[target_years >= min_target_year]
  }
  if (!is.null(max_target_year)) {
    target_years <- as.integer(substr(yearmon_from_months_since_jan_1960(svals + lead_months), 1, 4))
    svals <- svals[target_years <= max_target_year]
  }

  if (is.null(members)) {
    members <- ncdf4::ncvar_get(nc, 'M')
  }

  ncdf4::nc_close(nc)

  if (progress) {
    bar <- utils::txtProgressBar(min=0, max=length(members)*length(svals))
  }


  v <- list()
  i <- 1
  for (member in members) {
    for (s in svals) {
      v[[i]] <- read_vars(sprintf('%s::%s', fname, var),
                  extra_dims=list(S=s, M=member, L=lead_months+0.5))$data[[1]]
      i <- i+1

      if (progress) {
        utils::setTxtProgressBar(bar, i)
      }
    }
  }

  if (progress) {
    close(bar)
  }

  abind::abind(v, along=3)
}
