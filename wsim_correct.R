#!/usr/bin/env Rscript

# Copyright (c) 2018-2019 ISciences, LLC.
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

Usage: wsim_correct --retro=<file>... --obs=<file>... --forecast=<file>... --output=<file> [--attr=<attr>]... [--append]

Options:
--retro <file>    One or more netCDFs containing distribution fit parameters from retrospective forecast data (T in C, Pr in mm/month)
--obs <file>      One or more netCDFs containing distribution fit parameters from observed data (T in C, Pr in mm/month)
--forecast <file> One or more raster files containing forecast data to be corrected (T in K, Pr in mm/s)
--output <file>   A netCDF file of bias-corrected data (T in C, Pr in mm/month)
--attr <attr>     Optional attribute(s) to write to output netCDF file
--append          Append output to existing file
'->usage

check_unit_consistency <- function(var, retro_units, forecast_units) {
  if (is.null(retro_units)) {
    stop(sprintf("Unspecified units for retrospective forecast fit of %s", var))
  }

  if (is.null(forecast_units)) {
    stop(sprintf("Unspecified units for forecast of %s", var))
  }

  if (!is.null(retro_units) && !is.null(forecast_units) && retro_units != forecast_units) {
    stop(sprintf("Forecast uses units of %s but retrospective forecast distribution uses units of %s.", forecast_units, retro_units))
  }
}

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
  attrs <- lapply(args$attr, wsim.io::parse_attr)

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

      retro_units <- attr(retro_fit, 'units')
      forecast_units <- attr(forecast$data[[var]], 'units')
      observed_units <- attr(obs_fit, 'units')

      # forecast units need not be the same as observed distribution units, since
      # we're just matching quantiles
      check_unit_consistency(var, retro_units, forecast_units)

      corrected[[var]] = wsim.distributions::forecast_correct(distribution,
                                                              forecast$data[[var]],
                                                              retro_fit,
                                                              obs_fit)

      wsim.io::info('Computed bias-corrected values for', var)

      attrs <- c(attrs, list(
        list(var=var, key="comment", val=sprintf("bias-corrected according to %s fit data in %s and %s",
                                                 distribution,
                                                 attr(retro_fit, 'filename'),
                                                 attr(obs_fit, 'filename'))),
        list(var=var, key="units", val=observed_units),
        list(var=var, key="standard_name", val=attr(forecast$data[[var]], 'standard_name'))
      ))
    }
  }

  wsim.io::write_vars_to_cdf(corrected,
                             args$output,
                             extent= extent,
                             attrs=attrs,
                             prec='single',
                             append=args$append)

  wsim.io::info('Wrote corrected forecast to', args$output)
}

tryCatch(main(commandArgs(trailingOnly=TRUE)), error=wsim.io::die_with_message)
