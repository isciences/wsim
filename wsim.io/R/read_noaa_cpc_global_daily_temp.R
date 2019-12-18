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

#' Read a binary file of global daily temperatures from CPC
#'
#' Data available from \code{ftp://ftp.cpc.ncep.noaa.gov/precip/PEOPLE/wd52ws/global_temp/}
#'
#' @param fname     path to file
#' @param varname   name of variable to extract (one of \code{tmax}, \code{nmax},
#'                  \code{tmin}, \code{nmin})
#' @param day_start first day of year to extract
#' @param day_end   last day of year to extract
#' @return a 360x720xN array of daily values for \code{varname}
#' @export
read_noaa_cpc_global_daily_temp <- function(fname, varname, day_start, day_end) {
  nx <- 720
  ny <- 360
  valsz <- 4
  vars <- c('tmax', 'nmax', 'tmin', 'nmin')
  na_val <- -999
  endian <- 'little'

  varind <- which(vars == varname)
  stopifnot(length(varind) == 1)
  stopifnot(day_start > 0)
  stopifnot(day_start <= day_end)

  if (endsWith(fname, '.gz')) {
    fh <- gzfile(fname, 'rb')
  } else {
    fh <- file(fname, 'rb')
  }

  current_record <- 1

  read_slice <- function() {
    vals <- readBin(fh, 'numeric', n=ny*nx, size=valsz, endian=endian)
    stopifnot(length(vals) == ny*nx)
    matrix(vals, nrow=ny, ncol=nx, byrow=TRUE)
  }

  # seek doesn't work in a gzfile, so we read and discard
  skip_record <- function() {
    current_record <<- current_record + 1
    for (i in seq_along(vars)) {
      read_slice()
    }
  }

  read_record <- function() {
    current_record <<- current_record + 1
    for (i in seq_along(vars)) {
      if (i == varind) {
        vals <- read_slice()
      } else {
        read_slice()
      }
    }

    vals[vals == na_val] <- NA

    if(all(is.na(vals))) {
      stop(sprintf('No data found for day %d in %s', current_record, fname))
    }

    return(cbind(vals[ny:1, ((nx/2)+1):nx], vals[ny:1, 1:(nx/2)]))
  }


  for (i in seq_len(day_start - 1)) {
    skip_record()
  }

  ret <- replicate(day_end - day_start + 1,
                                read_record(),
                                simplify=FALSE)

  close(fh)

  abind::abind(ret, along=3)
}
