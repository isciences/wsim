#!/usr/bin/env Rscript

# Copyright (c) 2021 ISciences, LLC.
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

wsim.io::logging_init('calc_era5_wetdays')

suppressMessages({
  library(abind)
  library(lubridate)
  library(ncdf4)
  library(wsim.io)
  library(wsim.distributions)
})

'
Extract the fraction of days with non-trace precipitation

Usage: calc_era5_wetdays --input=<file> --output=<file> [--threshold=<amount>]

Options:
--input <file>          ERA5 hourly precipitation for 1 month, netCDF format
--output <file>         Output file, netCDF
--threshold <amount>    Minimum non-trace precipitation amount, mm [default: 0.1]
'->usage

main <- function(raw_args) {
  args <- parse_args(usage, raw_args, types=list(threshold = 'numeric'))

  nc <- nc_open(args$input)

  # time dimension is expressed as hours relate to an intial time
  initial_time <- ymd_hms(ncatt_get(nc, 'time', 'units')$value)

  hours <- nc$dim$time$vals
  days <- hours %/% 24

  # read the first hour to get the grid extent
  extent <- wsim.io::read_vars_from_cdf(args$input,
                                        vars = 'tp',
                                        extra_dims = list(time = hours[1]))$extent

  infof('Reading hourly data for %d days from %s', length(unique(days)), args$input)

  daily_precip_m <- abind(lapply(unique(days), function(day) {
    hours_since_initial_time = hours[days == day]
    stopifnot(length(hours_since_initial_time) == 24)

    hourly_precip <- abind(lapply(hours_since_initial_time, function(hour) {
      wsim.io::read_vars_from_cdf(args$input,
                                  vars = 'tp',
                                  extra_dims = list(time = hour))$data$tp
    }), along = 3)

    wsim.distributions::stack_sum(hourly_precip)
  }), along = 3)

  wetdays <- wsim.distributions::stack_frac_defined_above_zero(daily_precip_m * 1000 - args$threshold)

  infof('Writing output to %s', args$output)
  write_vars_to_cdf(vars = list(pWetDays = wetdays),
                    filename = args$output,
                    extent = extent)
}

tryCatch(
main(commandArgs(trailingOnly=TRUE))
,error=wsim.io::die_with_message)
