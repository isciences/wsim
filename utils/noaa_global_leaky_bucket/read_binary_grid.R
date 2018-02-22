#!/usr/bin/env Rscript

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

'
Reads monthly average temperature and precipitation from gridded files provided by NOAA

Usage: read_binary_grid (--input=<file> --var=<varname> --yearmon=<yearmon> --output=<file>) [--begin_date=<yyyymm>]

Options:
--input <file>         File to read
--output <file>        Name of output file
--var <varname>        Indicates whether [T]emperature or [P]recipitation should be read
--yearmon <yearmon>    Year and month of data to read
--begin_date <yyyymm>  Start date of data in the file [default: 194801]
'->usage

suppressMessages({
  require(wsim.io)
})

logging_init('read_binary_grid')

#' Compute the storage size of a grid, accounting for padding
#'
#' @param nx number of columns in grid
#' @param ny number of rows in grid
#'
#' @return size of grid data in bytes
grid_size_with_padding <- function(nx, ny) {
  4 + # padding
  4*nx*ny + #data
  4 #padding
}

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
#' @param yearmon      ending month of data file
#' @param nx           number of columns in each grid
#' @param ny           number of rows in each grid:W
seek_to_month <- function(fh, init_yearmon, yearmon, nx, ny) {
  n <- months_diff(init_yearmon, yearmon)
  seek(fh, where=n*grid_size_with_padding(nx, ny), origin='start')
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
      list(var='T', key='long_name', val='Temperature'),
      list(var='T', key='standard_name', val='surface_temperature'),
      list(var='T', key='units', val='degree_Celsius')
  ),
  P=list(
      list(var='P', key='long_name', val='Precipitation'),
      list(var='P', key='standard_name', val='precipitation_amount'),
      list(var='P', key='units', val='mm')
  )
)

main <- function(raw_args) {
  args <- parse_args(usage, raw_args)

  year <- as.integer(substr(args$yearmon, 1, 4))
  month <- as.integer(substr(args$yearmon, 5, 6))

  infile <- file(args$input, 'rb')

  attrs <- standard_attrs[[args$var]]
  if (is.null(attrs)) {
    die_with_message("Unknown variable ", args$var)
  }

  if (!wsim.io::can_write(args$output)) {
    die_with_message('Could not open', args$output, 'for writing.')
  }

  seek_to_month(infile, args$begin_date, args$yearmon, 720, 360)

  dat <- read_binary_grid(infile, 720, 360)

  if (is.null(dat)) {
    die_with_message('Could not read data for',  args$yearmon,
                     'from', paste0(args$input, '.'),
                     'Does the file need to be updated?')
  } else {
    info('Read data for', args$yearmon)
  }

  to_write <- list()
  to_write[[args$var]] <- dat

  write_vars_to_cdf(to_write,
                    args$output,
                    extent=c(-180, 180, -90, 90),
                    attrs=attrs)

}

#if (!interactive()) {
#  tryCatch(main(commandArgs(trailingOnly=TRUE)), error=die_with_message)
#}
main(commandArgs(trailingOnly=TRUE))
