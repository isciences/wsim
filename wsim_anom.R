#!/usr/bin/env Rscript

# Copyright (c) 2018-2020 ISciences, LLC.
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
Compute standardized anomalies and/or return periods

Usage: wsim_anom --fits=<fits>... --obs=<file>... [--sa=<file>] [--rp=<file>] [--attr=<attr>]...

Options:
--fits <file>  netCDF file containing distribution fit parameters
--obs <file>   Raster file containing observed values
--sa <file>    output location for netCDF file of standardized anomalies
--rp <file>    output location for netCDF file of return periods
--attr <attr>  optional attributes to attach to output netCDF(s)
'->usage

main <- function(raw_args) {
  args <- parse_args(usage, raw_args)
  
  attrs <- lapply(args$attr, wsim.io::parse_attr)

  if (is.null(args$sa) && is.null(args$rp)) {
    die_with_message("Must write return periods or standardized anomalies (--rp and/or --sa)")
  }

  for (outfile in c(args$sa, args$rp)) {
    if (!is.null(outfile) && !can_write(outfile)) {
      die_with_message("Cannot open ", outfile, " for writing.")
    }
  }

  fits <- wsim.io::read_fits_from_cdf(args$fits)

  extent <- attr(fits[[1]], 'extent')
  ids <- attr(fits[[1]], 'ids')
  sa_to_write <- list()
  rp_to_write <- list()

  writing_sa <- !is.null(args$sa)
  writing_rp <- !is.null(args$rp)

  for (obs_arg in args$obs) {
    v <- wsim.io::read_vars(obs_arg,
                            expect.extent=extent,
                            expect.ids=ids,
                            expect.dims=dim(fits)[1:2])
    for (varname in names(v$data)) {
      obs <- v$data[[varname]]
      fit <- fits[[varname]]

      if (is.null(fit)) {
        die_with_message("No fit provided for input variable", varname)
      }

      distribution <- attr(fit, 'distribution')

      sa <- standard_anomaly(distribution, fit, obs)

      wsim.io::info("Computed standardized anomalies for", varname)

      if (writing_sa) {
        sa_to_write[[paste0(varname, '_sa')]] <- sa
      }

      if (writing_rp) {
        rp <- sa2rp(sa)
        rp_to_write[[paste0(varname, '_rp')]] <- rp
      }

      attr(fits[[varname]], 'used') <- TRUE
    }
  }

  if (writing_sa) {
    write_vars_to_cdf(sa_to_write,
                      filename=args$sa,
                      extent=extent,
                      ids=ids,
                      prec='single',
                      attrs=attrs,
                      append=TRUE)
    wsim.io::info("Wrote standard anomalies to", args$sa)
  }

  if (writing_rp) {
    write_vars_to_cdf(rp_to_write,
                      filename=args$rp,
                      extent=extent,
                      ids=ids,
                      prec='single',
                      attrs=attrs,
                      append=TRUE)
    wsim.io::info("Wrote return periods to", args$rp)
  }

  warn_unused_fits(fits)
}

# Emit a warning for any fits that weren't flagged as "used"
# This is to try into catch possible errors with command-line arguments.
warn_unused_fits <- function(fits) {
  for (varname in names(fits)) {
    fit <- fits[[varname]]

    if (!('used' %in% names(attributes(fit)) && attr(fit, 'used', exact=TRUE))) {
      wsim.io::warn("Fits for variable", varname, "were loaded but never used.")
    }
  }
}

tryCatch(main(commandArgs(trailingOnly=TRUE)), error=wsim.io::die_with_message)
