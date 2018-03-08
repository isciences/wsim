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

wsim.io::logging_init('wsim_correct')
suppressMessages(require(Rcpp))

'
Bias-correct a forecast file

Usage: wsim_correct --retro=<file>... --obs=<file>... --forecast=<file>... --output=<file> [--append]

Options:
--retro <file>    One or more netCDFs containing distribution fit parameters from retrospective forecast data (T in C, Pr in mm/month)
--obs <file>      One or more netCDFs containing distribution fit parameters from observed data (T in C, Pr in mm/month)
--forecast <file> One or more raster files containing forecast data to be corrected (T in K, Pr in mm/s)
--output <file>   A netCDF file of bias-corrected data (T in C, Pr in mm/month)
--append          Append output to existing file
'->usage

main <- function(raw_args) {
  args <- wsim.io::parse_args(usage, raw_args)

  wsim.io::info('Reading retrospective forecast fit parameters')
  retro_fits <- wsim.io::read_fits_from_cdf(args$retro)

  wsim.io::info('Reading observed value fit parameters')
  obs_fits <- wsim.io::read_fits_from_cdf(args$obs)

  extent <- attr(retro_fits[[1]], 'extent')

  check_extent <- function(cube) {
    stopifnot(all(attr(cube, 'extent') == extent))
  }

  check_extent(obs_fits)

  corrected <- list()
  attrs <- list()

  for (input in args$forecast) {
    forecast <- wsim.io::read_vars(input)
    wsim.io::info('Read forecast from', args$forecast)

    for (var in names(forecast$data)) {
      retro_fit <- retro_fits[[var]]
      obs_fit <- obs_fits[[var]]

      if (is.null(retro_fit)) {
        wsim.io::die_with_message("No retrospective forecast fit provided for input variable", var)
      }

      if (is.null(obs_fit)) {
        wsim.io::die_with_message("No observed fit provided for input variable", var)
      }

      distribution <- attr(retro_fit, 'distribution')
      stopifnot(distribution == attr(obs_fit, 'distribution'))

      corrected[[var]] = wsim.distributions::forecast_correct(distribution,
                                                              forecast$data[[var]],
                                                              retro_fit,
                                                              obs_fit)

      wsim.io::info('Computed bias-corrected values for', var)

      attrs <- c(attrs, list(
        list(var=var, key="comment", val=paste0("bias-corrected according to ",
                                                             distribution,
                                                             " fit data in ",
                                                             attr(retro_fit, 'filename'),
                                                             " and ",
                                                             attr(obs_fit, 'filename')))
      ))
    }
  }

  wsim.io::write_vars_to_cdf(corrected,
                             args$output,
                             extent= extent,
                             attrs=attrs,
                             append=args$append)

  wsim.io::info('Wrote corrected forecast to', args$output)
}

tryCatch(main(commandArgs(trailingOnly=TRUE)), error=wsim.io::die_with_message)
