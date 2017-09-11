#!/usr/bin/env Rscript

suppressMessages({
  require(wsim.distributions)
  require(wsim.io)
  require(abind)
})

'
Fit statistical distributions.

Usage: wsim_fit (--distribution=<dist>) (--input=<file>)... (--output=<file>) [--cores=<num>]

--distribution <dist> the statistical distribution to be fit
--input <file>        Files to read observations
--ouput <file>        Output netCDF file with distribution fit parameters
--cores <num>         Number of CPU cores to use [default: 1]
'->usage

main <- function(args) {
  args <- parse_args(usage, args)

  outfile <- args$output
  if (!can_write(outfile)) {
    die_with_message("Cannot open ", outfile, " for writing.")
  }

  if (args$cores > 1) {
    c1 <- parallel::makeCluster(4)
    parallel::setDefaultCluster(c1)
  }

  inputs <- lapply(expand_inputs(args$input), wsim.io::load_matrix)
  extent <- attr(inputs[[1]], 'extent')

  inputs_stacked <- abind(inputs, along=3)

  distribution <- tolower(args$distribution)

  if (distribution == 'gev') {
    fits <- fitGEV(inputs_stacked)
  } else {
    die_with_message(distribution, " is not a supported statistical distribution.")
  }

  write_vars_to_cdf(fits, outfile, extent=extent, attrs=list(list(var=NULL,key="distribution",val=distribution)))
}

main(commandArgs(TRUE))
