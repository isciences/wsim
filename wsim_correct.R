#!/usr/bin/env Rscript
wsim.io::logging_init('wsim_correct')
suppressMessages(require(Rcpp))

'
Bias-correct a forecast file

Usage: wsim_correct --retro=<file> --obs=<file> --forecast=<file> --output=<file> [--append]

Options:
--retro <file>    A netCDF containing distribution fit parameters from retrospective forecast data (T in C, Pr in mm/month)
--obs <file>      A netCDF containing distribution fit parameters from observed data (T in C, Pr in mm/month)
--forecast <file> A raster file containing forecast data to be corrected (T in K, Pr in mm/s)
--output <file>   A netCDF file of bias-corrected data (T in C, Pr in mm/month)
--append          Append output to existing file
'->usage

main <- function(raw_args) {
  args <- wsim.io::parse_args(usage, raw_args)

  retro_fits <- wsim.io::read_vars_to_cube(args$retro, attrs_to_read=c('distribution'))

  wsim.io::info('Read retrospective forecast fit parameters (', attr(retro_fits, 'distribution'), ') from ', args$retro)

  obs_fits <- wsim.io::read_vars_to_cube(args$obs, attrs_to_read=c('distribution'))

  wsim.io::info('Read observed value fit parameters (', attr(obs_fits, 'distribution'), ') from ', args$obs)

  extent <- attr(retro_fits, 'extent')

  check_extent <- function(cube) {
    stopifnot(all(attr(cube, 'extent') == extent))
  }

  check_extent(obs_fits)

  distribution <- attr(retro_fits, 'distribution')

  stopifnot(attr(retro_fits, 'distribution') ==
            attr(obs_fits,   'distribution'))

  forecast <- wsim.io::read_vars(args$forecast)

  # CFS forecasts converted to netCDF using the NCL script have incorrectly
  # flipped longitudes. Fix that here.
  # forecast$data[[1]] <- apply(forecast$data[[1]], 2, rev)

  wsim.io::info('Read forecast from', args$forecast)

  if (length(names(forecast$data)) != 1) {
    wsim.io::die_with_message("Expected to read exactly one variable from ", args$forecast, " (found ", length(names(forecast$data)), ")")
  }

  # TODO check extents?

  varname <- names(forecast$data)[[1]]

  corrected <- list()
  corrected[[varname]] <- wsim.distributions::forecast_correct(distribution, forecast$data[[1]], retro_fits, obs_fits)

  wsim.io::write_vars_to_cdf(corrected,
                             args$output,
                             extent= extent,
                             attrs=list(
                               list(var=varname, key="comment", val=paste0("bias-corrected according to ",
                                                                           distribution,
                                                                           " fit data in ",
                                                                           args$retro,
                                                                           " and ",
                                                                           args$obs))
                             ),
                             append=args$append)
  wsim.io::info('Wrote corrected forecast to', args$output)
}

tryCatch(main(commandArgs(trailingOnly=TRUE)), error=wsim.io::die_with_message)
