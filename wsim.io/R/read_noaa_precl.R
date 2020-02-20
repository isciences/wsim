# Copyright (c) 2019-2020 ISciences, LLC.
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

#' Read a gridded 0.5-degree PREC/L binary file
#'
#' PREC/L files are distributed in a custom binary format at the following URL:
#' ftp://ftp.cpc.ncep.noaa.gov/precip/50yr/gauge/0.5deg/format_bin_lnx/
#'
#' Each file contains up to 12 months of precipitation data in mm/month.
#'
#' @param fname the file name to read
#' @param month the month to read
#' @return a 360x720 matrix of precipitation rates in mm/s
#' @export
read_noaa_precl <- function(fname, month) {
  stopifnot(month %in% 1:12)

  # Hardcoded grid parameters, described in:
  # ftp://ftp.cpc.ncep.noaa.gov/precip/50yr/gauge/0.5deg/format_bin_lnx/README.txt
  nx <- 720
  ny <- 360
  valsz <- 4
  na_val <- -999
  endian <- 'little'

  fh <- file(fname, 'rb')

  seek(fh, precl_byte_offset(month, 1), origin='start')

  vals <- matrix(
    readBin(fh, 'numeric', n=ny*nx, size=valsz, endian=endian),
    nrow=ny,
    ncol=nx,
    byrow=TRUE)

  close(fh)

  vals[vals == na_val] <- NA
  # Flip rows, switch from 0-360 to -180-180, and change units from
  # tenths-of-millimeters/day to mm/s
  cbind(vals[ny:1, ((nx/2)+1):nx], vals[ny:1, 1:(nx/2)]) * 0.1 / 24 / 3600
}

#' Download a month of PREC/L data and write to netCDF
#'
#' @param fname of output filename
#' @param year year to download
#' @param month month to download
#' @export
download_precl <- function(fname, year, month) {
  start <- precl_byte_offset(month, 1)
  stop <- precl_byte_offset(month + 1, 1) - 1

  url <- precl_url(year)

  temp_fname <- tempfile()

  curl_range(url, start, stop, temp_fname)

  dat <- read_noaa_precl(temp_fname, 1)

  file.remove(temp_fname)

  write_vars_to_cdf(list(Pr=dat),
                    fname,
                    extent=c(-180, 180, -90, 90),
                    attrs=list(
                      list(var="Pr", key="standard_name", val="precipitation_flux"),
                      list(var="Pr", key="long_name", val="Precipitation Rate"),
                      list(var="Pr", key="units", val="kg/m^2/s")
                    ),
                    prec='single')
  infof("Wrote PREC/L data to %s", fname)
}

#' Download a range of bytes from a URL using curl
#'
#' @param url url to access
#' @param start first byte to read (0-indexed, inclusive)
#' @param stop last byte to read (0-indexed, inclusive)
#' @param fname output filename
#' @param timeout timeout in seconds
#' @export
curl_range <- function(url, start, stop, fname, timeout=NULL) {
  expected_size <- (stop - start) + 1
  infof('Downloading %d bytes (%d - %d) from %s', expected_size, start, stop, url)

  args <- c('-r', sprintf('%d-%d', start, stop),
            '-o', fname)
  if (!is.null(timeout)) {
    args <- c(args, '--max-time', timeout)
  }

  # We can't check curl return code because it may download all of the
  # data and then time out while closing the connection. So we call it
  # a success if we got as many bytes as we asked for.
  system2('curl',
          args=c(args, url),
          stdout=FALSE,
          stderr=FALSE)

  received_size <- file.size(fname)
  if (received_size != expected_size) {
    stop(sprintf('Failed to download bytes %d-%d from %s (received %d bytes)', start, stop, url, received_size))
  }
}

#' Return the FTP url for a PREC/L binary file
#' @param year year of observation
#' @return url
precl_url <- function(year) {
  sprintf('ftp://ftp.cpc.ncep.noaa.gov/precip/50yr/gauge/0.5deg/format_bin_lnx/precl_mon_v1.0.lnx.%04d.gri0.5m', year)
}

#' Return the number of bytes from the start of a PREC/L binary file until a given pixel in a given month
#'
#' @param month month of data
#' @param pixel pixel in image (1 for start of image)
#' @return offset in bytes
precl_byte_offset <- function(month, pixel) {
  nx <- 720
  ny <- 360
  valsz <- 4

  recsize <- nx*nx*valsz

  (month-1)*recsize + (pixel-1)*valsz
}

#' Return TRUE if PREC/L data is available for a given year/month
#'
#' @param year year to test
#' @param month month to test
#' @return TRUE if the data is available by FTP
is_precl_available <- function(year, month) {
  stopifnot(month %in% 1:12)

  test_pixel <- 30

  url <- precl_url(year)

  is_byte_defined(url,
                  precl_byte_offset(month, test_pixel),
                  4,
                  'little',
                  -999)
}

#' Check is a given pixel is defined in a file accessible through a URL
#'
#' @param url      url to probe
#' @param position intial position to read from \code{url} (0-indexed)
#' @param size     number of bytes to read
#' @param endian   endianness of data, e.g. \code{"little"}
#' @param nodata_value value indicating missing data, e.g. \code{-999}
#'
#' @return TRUE if the byte is defined, FALSE otherwise
is_byte_defined <- function(url, position, size, endian, nodata_value) {
  fname <- tempfile()

  stop <- position + (size-1)

  curl_range(position, stop)

  result <- isTRUE(readBin(fname, 'numeric', n=1, size=size, endian=endian) != nodata_value)
  file.remove(fname)

  result
}
