#!/usr/bin/env Rscript

'
Fit statistical distributions.

Usage: wsim_fit (--distribution=<dist>) (--input=<file>)... (--output=<file>) [--cores=<num>]

--distribution <dist> the statistical distribution to be fit
--input <file>        Files to read observations
--ouput <file>        Output netCDF file with distribution fit parameters
--cores <num>         Number of CPU cores to use [default: 1]
'->usage

main <- function(raw_args) {
  args <- wsim.io::parse_args(usage, raw_args)

  outfile <- args$output
  if (!wsim.io::can_write(outfile)) {
    die_with_message("Cannot open ", outfile, " for writing.")
  }

  if (args$cores > 1) {
    c1 <- parallel::makeCluster(4)
    parallel::setDefaultCluster(c1)
  }

  inputs_stacked <- wsim.io::read_vars_to_cube(wsim.io::expand_inputs(args$input))
  extent <- attr(inputs_stacked, 'extent')

  cat('Read', dim(inputs_stacked)[[3]], 'inputs.\n')

  distribution <- tolower(args$distribution)

  if (distribution == 'gev') {
    fits <- wsim.distributions::fitGEV(inputs_stacked)
  } else {
    wsim.io::die_with_message(distribution, " is not a supported statistical distribution.")
  }

  wsim.io::write_vars_to_cdf(fits,
                             outfile,
                             extent=extent,
                             attrs=list(
                               list(var=NULL,key="distribution",val=distribution)
                             ))

  cat('Wrote fits to ', outfile, '.\n', sep="")
}

main(commandArgs(TRUE))
