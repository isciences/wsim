#!/usr/bin/env Rscript

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

'
Download CPC Global Daily Temperature data and compute monthly means

Usage: get_cpc_monthly_mean_temperature.R (--workdir=<dirname> --yearmon=<yearmon> --output=<file>)

Options:
--yearmon <yearmon>    Year and month of data to read
--workdir <dirname>    Path of working directory where raw files are stored
--output <file>        Path of output netCDF file
'->usage

suppressMessages({
  library(wsim.io)
  library(lubridate)
})

logging_init('get_cpc_monthly_mean_temperature')

missing_dates <- c(
  '19810101',
  '19810102',
  '19830426',
  '19830427',
  '19830428',
  '19830429',
  '19830430',
  '19840107',
  '19850101',
  '19850107',
  '19850108',
  '19850112',
  '19850113',
  '19850116',
  '19850119',
  '19850206',
  '19850717',
  '19850810',
  '19860104',
  '19860328',
  '19860920',
  '19861114',
  '19861121',
  '19920731'
)

get_missing_dates <- function(year, month) {
  yearmon <- sprintf('%04d%02d', year, month)
  as.integer(substr(missing_dates[startsWith(missing_dates, yearmon)], 7, 8))
}

check_missing_data <- function(dat, year, month) {
  missing_days <- get_missing_dates(year, month)
  days <- seq_len(days_in_month(ISOdate(year, month, 1)))

  for (i in setdiff(days, missing_days)) {
    if (all(is.na(dat[,,i]))) {
      stop(sprintf('Data missing for %04d-%02d-%02d', year, month, i))
    }
  }
}

byte_offset <- function(day, pixel=1) {
  sz <- 4
  nx <- 720
  ny <- 360
  nvars <- 4

  ((day-1)*nx*ny*nvars + (pixel - 1))*sz
}

day_number <- function(year, month, day) {
  as.integer(strftime(ISOdate(year, month, day), '%j'))
}

#' Download days from \code{first_day} to \code{last_day} to a temporary file, and return that file
download_days <- function(url, first_day, last_day) {
  start <- byte_offset(first_day)
  stop  <- byte_offset(last_day + 1) - 1

  fname <- tempfile()

  expected_size <- (stop - start) + 1
  infof('Downloading %d bytes (%d - %d) from %s', expected_size, start, stop, url)

  system2('curl',
          args=c('-r', sprintf('%d-%d', start, stop),
                 '-o', fname,
                 url),
          stdout=FALSE,
          stderr=FALSE)

  # We can't check curl return code because it may download all of the
  # data and then time out while closing the connection. So we call it
  # a success if we got as many bytes as we asked for.
  received_size <- file.size(fname)
  if (received_size != expected_size) {
    stop(sprintf('Failed to download bytes %d-%d from %s (received %d bytes)', start, stop, url, received_size))
  }

  fname
}

#' Check whether a date is available in an uncompressed file
is_date_available <- function(url, year, month, day) {
  pixel <- 98200
  start <- byte_offset(day_number(year, month, day), pixel)
  stop <- start + 3

  fname <- tempfile()

  system2('curl',
          args=c('-r', sprintf('%d-%d', start, stop),
                 '--max-time', 3,
                 '-o', fname,
                 url),
          stdout=FALSE,
          stderr=FALSE)

  result <- isTRUE(readBin(fname, 'numeric', n=1, size=4, endian='little') != -999)
  file.remove(fname)

  result
}

main <- function(raw_args) {
  args <- parse_args(usage, raw_args)

  year <- as.integer(substr(args$yearmon, 1, 4))
  month <- as.integer(substr(args$yearmon, 5, 6))
  outfile <- args$output
  workdir <- args$workdir

  if (!can_write(outfile)) {
    stop(sprintf('Cannot write to %s. Does the directory exist?', outfile))
  }

  if (!dir.exists(workdir)) {
    dir.create(workdir, recursive=TRUE)
  }

  start_doy <- day_number(year, month, 1)
  end_doy <- day_number(year, month, days_in_month(ISOdate(year, month, 1)))

  file_url <- sprintf('ftp://ftp.cpc.ncep.noaa.gov/precip/PEOPLE/wd52ws/global_temp/CPC_GLOBAL_T_V0.x_0.5deg.lnx.%04d.gz', year)
  file_name <- sprintf('CPC_GLOBAL_T_V0.x_0.5deg.lnx.%04d.gz', year)

  fpath <- file.path(workdir, file_name)

  # We have to go through a few hoops to find the data. For a completed year, the data will probably
  # be found in gzipped format. For the most recent year, the data will probably be found uncompressed.
  # Since we have no way to know if the files have been gzipped yet, we have to check for both
  # cases.
  found_gzfile <- file.exists(fpath)
  if (!found_gzfile) {
    infof('Attempting to download compressed data for %s', year)
    # No need to panic if the file doesn't exist, so squelch any noisy output.
    try({
      suppressWarnings({
        found_gzfile <- (download.file(file_url, fpath, quiet=TRUE) == 0)
      })
    }, silent=TRUE)
  }

  if (!found_gzfile) {
    infof('Compressed data not found for %s. Checking for uncompressed data.', year)

    # Now things get weird. If the uncompressed file is found, it may or may not include data for
    # the month of interest. But we can't determine this from the file size alone; if the data is
    # not yet available, the file will still be present and populated with NODATA value. So we
    # carefully construct an FTP request for a single byte, representing a pixel that should have
    # data, on the last day of the month.
    uncompressed_url <- sub('.gz', '', file_url, fixed=TRUE)

    last_day_in_month <- days_in_month(ISOdate(year, month, 1))
    if (is_date_available(uncompressed_url, year, month, last_day_in_month)) {
      infof('Data is available for %04d-%02d-%02d. Downloading.', year, month, last_day_in_month)
      # It looks like the requested data is available, so we now download all dates of interest
      # to a temporary file.
      fpath <- download_days(uncompressed_url, start_doy, end_doy)
      end_doy <- (end_doy - start_doy) + 1
      start_doy <- 1
    } else {
      stop(sprintf('Data not yet available for %04d-%02d-%02d', year, month, last_day_in_month))
    }
  }

  infof('Extracting data for %04d%02d (days %d-%d) from %s', year, month, start_doy, end_doy, fpath)

  tmin <- read_noaa_cpc_global_daily_temp(fpath, 'tmin', start_doy, end_doy, check_defined=FALSE)
  tmax <- read_noaa_cpc_global_daily_temp(fpath, 'tmax', start_doy, end_doy, check_defined=FALSE)
  tavg <- 0.5*(tmin + tmax)

  # Make sure that values are defined, except for days known to be missing.
  check_missing_data(tavg, year, month)

  wsim.io::write_vars_to_cdf(
    vars = list(
      tmin = wsim.distributions::stack_mean(tmin),
      tmax = wsim.distributions::stack_mean(tmax),
      tavg = wsim.distributions::stack_mean(tavg)),
    filename = outfile,
    extent = c(-180, 180, -90, 90),
    attrs = list(
      list(var='tmin', key='units', val='degree_Celsius'),
      list(var='tmax', key='units', val='degree_Celsius'),
      list(var='tavg', key='units', val='degree_Celsius'),
      list(var='tavg', key='standard_name', val='surface_temperature')))

  infof('Wrote min, max, and avg temperatures for %04d%02d to %s', year, month, outfile)
}

tryCatch(main(commandArgs(trailingOnly=TRUE)),
         error=die_with_message)
