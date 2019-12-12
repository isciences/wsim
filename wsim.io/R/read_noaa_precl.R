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

#' Read a gridded 0.5-degree PREC/L binary file
#'
#' PREC/L files are distributed in a custom binary format at the following URL:
#' ftp://ftp.cpc.ncep.noaa.gov/precip/50yr/gauge/0.5deg/format_bin_lnx/
#'
#' Each file contains up to 12 months of precipitation data in mm/month.
#'
#' @param fname the file name to read
#' @param month the month to read
#' @return a 360x720 matrix of precipitation rates
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


  recsize <- nx*nx*valsz

  fh <- file(fname, 'rb')

  seek(fh, (month-1)*recsize, origin='start')

  vals <- matrix(
    readBin(fh, 'numeric', n=ny*nx, size=valsz, endian=endian),
    nrow=ny,
    ncol=nx,
    byrow=TRUE)

  close(fh)

  vals[vals == na_val] <- NA
  # Flip rows, switch from 0-360 to -180-180, and change units from
  # tenths-of-millimeters/day to mm/day
  cbind(vals[ny:1, ((nx/2)+1):nx], vals[ny:1, 1:(nx/2)]) * 0.1
}
