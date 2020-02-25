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

# Hardcoded grid parameters, described in:
# ftp://ftp.cpc.ncep.noaa.gov/precip/50yr/gauge/0.5deg/format_bin_lnx/README.txt
precl_nx <- 720
precl_ny <- 360
precl_valsz <- 4
precl_na_val <- -999
precl_endian <- 'little'

#' Read a gridded 0.5-degree PREC/L binary file
#'
#' PREC/L files are distributed in a custom binary format at the following URL:
#' ftp://ftp.cpc.ncep.noaa.gov/precip/50yr/gauge/0.5deg/format_bin_lnx/
#'
#' Each file contains up to 12 months of precipitation rates and gauge counts
#'
#' @param fname the file name to read
#' @param month the month to read
#' @param layer layer to retrieve (1 = precipitation rates, 2 = number of stations)
#' @return a an opened file handle, positioned at the given month/layer
#' @export
open_noaa_precl <- function(fname, month, layer=1) {
  stopifnot(month %in% 1:12)
  stopifnot(layer %in% 1:2)

  fh <- file(fname, 'rb')

  seek(fh, precl_byte_offset(month, 1, layer), origin='start')

  fh
}

#' Read precipitation rates or gauge counts from a file handle
#'
#' @param fh an open file handle pointing to the position to begin reading
#' @param what \code{precipitation_rate} or \code{gauge_count}
read_noaa_precl <- function(fh, what) {
  stopifnot(what %in% c('precipitation_rate', 'gauge_count'))

  vals <- matrix(
    readBin(fh, 'numeric', n=precl_ny*precl_nx, size=precl_valsz, endian=precl_endian),
    nrow=precl_ny,
    ncol=precl_nx,
    byrow=TRUE)

  close(fh)

  vals[vals == precl_na_val] <- NA

  # Flip rows, switch from 0-360 to -180-180
  vals <- cbind(vals[precl_ny:1, ((precl_nx/2)+1):precl_nx], vals[precl_ny:1, 1:(precl_nx/2)])

  if (what == 'precipitation_rate') {
    # Change units from tenths-of-millimeters/day to mm/s
    return(vals * 0.1 / 24 / 3600)
  } else {
    return(vals)
  }
}

#' Download a month of PREC/L precipitation data and write to netCDF
#'
#' @param fname of output filename
#' @param year year to download
#' @param month month to download
#' @inheritParams read_noaa_precl
#' @export
download_precl <- function(fname, year, month, what='precipitation_rate') {
  stopifnot(what %in% c('precipitation_rate', 'gauge_count'))
  stopifnot(year >= 1948)
  stopifnot(month %in% 1:12)

  data <- list()
  attrs <- list()

  for (w in what) {
    if (w == 'precipitation_rate') {
      start <- precl_byte_offset(month, pixel=1, layer=1)
      stop <- precl_byte_offset(month, pixel=1, layer=2) - 1

      varname <- 'Pr'

      attrs <- c(attrs,list(
        list(var=varname, key="standard_name", val="precipitation_flux"),
        list(var=varname, key="long_name", val="Precipitation Rate"),
        list(var=varname, key="units", val="kg/m^2/s")
      ))
    } else {
      start <- precl_byte_offset(month, pixel=1, layer=2)
      stop <- precl_byte_offset(month+1, pixel=1, layer=1) - 1

      varname <- 'num_stations'

      attrs <- c(attrs,list(
        list(var=varname, key="long_name", val="Number of Stations")
      ))
    }

    url <- precl_url(year)

    temp_fname <- tempfile()

    curl_range(url, start, stop, temp_fname)

    fh <- open_noaa_precl(temp_fname, 1, 1) # month/layer parameter is always 1 because we only downloaded one month
    data[[varname]] <- read_noaa_precl(fh, w)

    file.remove(temp_fname)
  }

  write_vars_to_cdf(data,
                    fname,
                    extent=c(-180, 180, -90, 90),
                    attrs=attrs,
                    prec=list(Pr='single', num_stations='byte'))
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
#' @param pixel pixel in image (1 for start of image)
#' @inheritParams open_noaa_precl
#' @return offset in bytes
precl_byte_offset <- function(month, pixel, layer) {
  recsize <- precl_nx*precl_ny*precl_valsz
  nlayers <- 2

  recsize*((month-1)*nlayers + (layer-1)) + (pixel-1)*precl_valsz
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
                  precl_byte_offset(month, test_pixel, 1),
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
