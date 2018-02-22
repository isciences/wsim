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

wsim.io::logging_init('wsim_anom')

suppressMessages({
  require(Rcpp)
  require(wsim.distributions)
  require(wsim.io)
})

'
Compute standard anomalies and/or return periods

Usage: wsim_anom --fits=<fits> --obs=<file> [--sa=<file>] [--rp=<file>]

Options:
--fits <file>  netCDF file containing distribution fit parameters
--obs <file>   Raster file containing observed values
--sa <file>    output location for netCDF file of standard anomalies
--rp <file>    output location for netCDF file of return periods
'->usage

main <- function(raw_args) {
  args <- parse_args(usage, raw_args)

  if (is.null(args$sa) && is.null(args$rp)) {
    die_with_message("Must write return periods or standard anomalies (--rp and/or --sa)")
  }

  for (outfile in c(args$sa, args$rp)) {
    if (!is.null(outfile) && !can_write(outfile)) {
      die_with_message("Cannot open ", outfile, " for writing.")
    }
  }

  fits <- wsim.io::read_vars_to_cube(args$fits, attrs_to_read=c('distribution'))
  distribution <- attr(fits, 'distribution')
  wsim.io::info("Read distribution parameters.")

  v <- wsim.io::read_vars_from_cdf(args$obs)
  obs <- v$data[[1]]
  varname <- names(v$data)[1]

  sa <- standard_anomaly(distribution, fits, obs)

  if (!is.null(args$sa)) {
    to_write <- list()
    to_write[[paste0(varname, '_sa')]] <- sa
    write_vars_to_cdf(to_write,
                      filename=args$sa,
                      extent=attr(fits, 'extent'),
                      prec='single',
                      append=TRUE)
    wsim.io::info("Wrote standard anomalies to", args$sa)
  }

  if (!is.null(args$rp)) {
    rp <- sa2rp(sa)

    to_write <- list()
    to_write[[paste0(varname, '_rp')]] <- rp

    write_vars_to_cdf(to_write,
                      filename=args$rp,
                      extent=attr(fits, 'extent'),
                      prec='single',
                      append=TRUE)
    wsim.io::info("Wrote return periods to", args$rp)
  }
}

tryCatch(main(commandArgs(trailingOnly=TRUE)), error=wsim.io::die_with_message)
