#!/usr/bin/env Rscript

# Copyright (c) 2022 ISciences, LLC.
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

wsim.io::logging_init('wsim_quantile')

suppressMessages({
  require(Rcpp)
  require(wsim.distributions)
  require(wsim.io)
})

'
Compute the value associated with a specified return period/standardized anomaly

Usage: wsim_quantile.R --fits=<fits>... [--median-when-undefined] [--sa=<number>] [--rp=<number>] [--attr=<attr>]... --output

Options:
--fits <file>            netCDF file containing distribution fit parameters
--sa <file>              standardized anomaly for which a value should be returned
--rp <file>              return period for which a value should be returned
--attr <attr>            optional attributes to attach to output netCDF(s)
--median-when-undefined  if --sa=0, return median value where distribution is
                         not defined but median is known
--output <file>          output location for netCDF file
'->usage

main <- function(raw_args) {
  args <- parse_args(usage, raw_args, types = list(rp = 'numeric', sa = 'numeric'))

  attrs <- lapply(args$attr, wsim.io::parse_attr)

  if (is.null(args$sa) == is.null(args$rp)) {
    die_with_message("Must specify exactly one of --rp or --sa")
  }

  if (!can_write(args$output)) {
    die_with_message("Cannot open ", args$output, " for writing.")
  }

  fits <- wsim.io::read_fits_from_cdf(args$fits)

  extent <- attr(fits[[1]], 'extent')
  ids <- attr(fits[[1]], 'ids')

  if (!is.null(args$rp)) {
    q <- stats::pnorm(wsim.distributions::rp2sa(args$rp))
  } else if (!is.null(args$sa)) {
    q <- stats::pnorm(args$sa)
  } else {
    stop('Unknown quantile.')
  }

  quantiles <- list()
  for (varname in names(fits)) {
    fit <- fits[[varname]]
    if (attr(fit, 'distribution') != 'gev') {
      stop('Arbitrary (non-GEV) distribution support not implemented yet.')
    }

    if (!is.null(ids)) {
      stop('Untested for id-based data.')
      # Not sure the fit indexing (fit[,,1]) will work here.
    }

    quantiles[[varname]] <- wsim.distributions::quagev(q, fit[,,1], fit[,,2], fit[,,3])
    if (q == 0.5 && args[['median_when_undefined']]) {
      median_px <- which(is.na(fit[,,2]) & !is.na(fit[,,1]))
      quantiles[[varname]][median_px] = fit[,,1][median_px]
    }

    # carry unit and standard_name attributes from fit to output
    attrs <- c(attrs, list(
      list(var=varname, key="units", val=attr(fit, 'units')),
      list(var=varname, key="standard_name", val=attr(fit, 'standard_name'))
    ))
  }

  write_vars_to_cdf(quantiles,
                    filename=args$output,
                    extent=extent,
                    ids=ids,
                    prec='single',
                    attrs=attrs,
                    append=FALSE)

  wsim.io::info("Wrote results to", args$output)
}

#tryCatch(
  main(commandArgs(trailingOnly=TRUE))
  #, error=wsim.io::die_with_message)
