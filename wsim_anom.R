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

Usage: wsim_anom --fits=<fits>... --obs=<file>... [--sa=<file>] [--rp=<file>]

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

  fits <- wsim.io::read_fits_from_cdf(args$fits)

  extent <- attr(fits[[1]], 'extent')
  sa_to_write <- list()
  rp_to_write <- list()

  writing_sa <- !is.null(args$sa)
  writing_rp <- !is.null(args$rp)

  for (obs_arg in args$obs) {
    v <- wsim.io::read_vars(obs_arg)
    for (varname in names(v$data)) {
      obs <- v$data[[varname]]
      fit <- fits[[varname]]

      if (is.null(fit)) {
        die_with_message("No fit provided for input variable", varname)
      }

      distribution <- attr(fit, 'distribution')

      sa <- standard_anomaly(distribution, fit, obs)
      wsim.io::info("Computed standard anomalies for", varname)

      if (writing_sa) {
        sa_to_write[[paste0(varname, '_sa')]] <- sa
      }

      if (writing_rp) {
        rp <- sa2rp(sa)
        rp_to_write[[paste0(varname, '_rp')]] <- rp
      }
    }
  }

  if (writing_sa) {
    write_vars_to_cdf(sa_to_write,
                      filename=args$sa,
                      extent=extent,
                      prec='single',
                      append=TRUE)
    wsim.io::info("Wrote standard anomalies to", args$sa)
  }

  if (writing_rp) {
    write_vars_to_cdf(rp_to_write,
                      filename=args$rp,
                      extent=extent,
                      prec='single',
                      append=TRUE)
    wsim.io::info("Wrote return periods to", args$rp)
  }
}

tryCatch(main(commandArgs(trailingOnly=TRUE)), error=wsim.io::die_with_message)
