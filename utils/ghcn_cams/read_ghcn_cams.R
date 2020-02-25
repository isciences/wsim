#!/usr/bin/env Rscript

# Copyright (c) 2020 ISciences, LLC.
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
Extracts a month from GHCN+CAMS gridded temperature dataset

Usage: read_ghcn_cams.R (--input=<file> --yearmon=<yearmon> --output=<file>) [--update_url=<url>]

Options:
--input <file>         File to read
--output <file>        Name of output file
--yearmon <yearmon>    Year and month of data to read
--update_url <url>     URL from which to update input file, if it does not contain requested year and month.
'->usage

suppressMessages({
  library(wsim.io)
})

logging_init('read_ghcn_cams')

#' Compute the number of months difference between two months
#'
#' @param a beginning month in YYYYMM character format
#' @param b ending month in YYYYMM character format
#'
#' @return number of months between b and a
months_diff <- function(a, b) {
  stopifnot(nchar(a) == 6)
  stopifnot(nchar(b) == 6)

  stopifnot(as.integer(substr(a, 5, 6)) <= 12)
  stopifnot(as.integer(substr(b, 5, 6)) <= 12)

  year_diff <- as.integer(substr(b, 1, 4)) - as.integer(substr(a, 1, 4))
  month_diff <- as.integer(substr(b, 5, 6)) - as.integer(substr(a, 5, 6))

  12*year_diff + month_diff
}

#' Seek to a given month in a binary file
#'
#' @param fh file handle
#' @param init_yearmon beginning month of data file
#' @param yearmon      month to seek to
#' @param nx           number of columns in each grid
#' @param ny           number of rows in each grid
seek_to_month <- function(fh, init_yearmon, yearmon, nx, ny) {
  n <- months_diff(init_yearmon, yearmon)
  seek(fh, where=n*grid_size_with_padding(nx, ny), origin='start')
}

#' Find latest month available in a binary file
#'
#' @param filename
#' @param init_yearmon beginning month of data file
#' @param nx           number of columns in each grid
#' @param ny           number of rows in each grid
get_last_month <- function(filename, init_yearmon, nx, ny) {
  n_months <- floor(file.size(filename) / grid_size_with_padding(nx, ny))

  year <- as.integer(substr(init_yearmon, 1, 4))
  month <- as.integer(substr(init_yearmon, 5, 6)) + (n_months - 1)
  while(month > 12) {
    year <- year + 1
    month <- month - 12
  }

  return(sprintf('%04d%02d', year, month))
}

#' Reads the marker value placed before or after a grid
#'
#' @param fh open file handle
#' @return the marker value, or NULL if the marker value is
#'         not present (we're at the end of the file)
read_marker <- function(fh) {
  marker <- readBin(fh, 'integer', n=1, size=4, endian='big')
  if (length(marker) == 0) {
    return(NULL)
  }
  return(marker)
}

#' Read a binary grid from a file
#'
#' @param fh       an open file handle
#' @param nx       number of columns in grid
#' @param ny       number of rows in grid
#' @param flip_y   if TRUE, rows will be flipped so that successive rows
#'                 represent decreasing latitudes
#' @param rotate_x if TRUE, columns will be rotated so that the first
#'                 column represents the prime meridian instead of
#'                 the antimeridian (0, 360) to (-180, 180)
read_binary_grid <- function(fh, nx, ny, na_value=-999.0, flip_y=TRUE, rotate_x=TRUE) {
  if (is.null(read_marker(fh))) {
    return(NULL)
  }

  vals <- matrix(
    readBin(fh, 'numeric', n=ny*nx, size=4, endian='big'),
    nrow=ny,
    ncol=nx,
    byrow=TRUE)

  read_marker(fh)

  vals[vals == na_value] <- NA

  if (flip_y) {
    vals <- apply(vals, 2, rev)
  }

  if (rotate_x) {
    vals <- vals[ , c((nx/2+1):nx, 1:(nx/2))]
  }

  return(vals)
}

standard_attrs <- list(
  T=list(
  ),
  P=list(
      list(var='P', key='long_name', val='Precipitation Rate'),
      list(var='P', key='standard_name', val='precipitation_flux'),
      list(var='P', key='units', val='kg/m^2/s')
  )
)

has_band <- function(fname, band_num) {
  x <- rgdal::GDAL.open(fname)
  ret <- !identical(rgdal::getRasterBand(x, band_num)@handle, new("externalptr"))
  rgdal::GDAL.close(x)
  return(ret)
}

main <- function(raw_args) {
  args <- parse_args(usage, raw_args)

  begin_date <- '194801'

  band <- 1L + months_diff(begin_date, args$yearmon)

  if(!has_band(args$input, band)) {
    if (!is.null(args$update_url)) {
      infof('Attempting to update %s via FTP...', basename(args$input))
      download.file(url=args$update_url, destfile=args$input, method='wget', extra=c('--continue'))

      if(!has_band(args$input, band)) {
        stop(sprintf('%s is up-to-date, but does not include data for %s.',
                     basename(args$input),
                     args$yearmon))
      }
    } else {
      stop(sprintf('%s does not include data for %s. You can update it with --update-url.',
                   args$yearmon))
    }
  }

  infof('Reading GHCN+CAMS data for %s from %s', args$yearmon, basename(args$input))

  #dat <- read_vars(make_vardef(args$input, list(make_var(as.character(band)))))$data[[1]]
  dat <- read_vars(sprintf('%s::%d', args$input, band))$data[[1]]
  infof('Read GHCN+CAMS data for %s from %s', args$yearmon, basename(args$input))

  # rotate from [0, 360] to [-180, 180]
  dat <- dat[, c(361:720,1:360)]

  write_vars_to_cdf(list(T=dat),
                    args$output,
                    extent=c(-180, 180, -90, 90),
                    attrs=list(
                      list(var='T', key='long_name', val='Temperature'),
                      list(var='T', key='standard_name', val='surface_temperature'),
                      list(var='T', key='units', val='degree_Celsius')
                    ))
  infof('Wrote GHCN+CAMS temperature for %s to %s', args$yearmon, args$output)
}

if (!interactive()) {
  tryCatch(
    main(commandArgs(trailingOnly=TRUE))
    , error=die_with_message)
}
