#!/usr/bin/env Rscript
wsim.io::logging_init('wsim_fit')

'
Fit statistical distributions.

Usage: wsim_fit (--distribution=<dist>) (--input=<file>)... (--output=<file>) [--cores=<num>]

--distribution <dist> the statistical distribution to be fit
--input <file>        Files to read observations
--ouput <file>        Output netCDF file with distribution fit parameters
--cores <num>         Number of CPU cores to use [default: 1]
'->usage

main <- function(raw_args) {
  args <- wsim.io::parse_args(usage, raw_args, types=list(cores="integer"))

  outfile <- args$output
  if (!wsim.io::can_write(outfile)) {
    wsim.io::die_with_message("Cannot open ", outfile, " for writing.")
  }

  if (args$cores > 1) {
    c1 <- parallel::makeCluster(args$cores)
    parallel::setDefaultCluster(c1)
  }

  inputs_stacked <- wsim.io::read_vars_to_cube(wsim.io::expand_inputs(args$input))
  extent <- attr(inputs_stacked, 'extent')

  wsim.io::info('Read', dim(inputs_stacked)[[3]], 'inputs.')

  distribution <- tolower(args$distribution)

  tryCatch({
    fits <- wsim.distributions::fit_cell_distributions(distribution,
                                                       inputs_stacked,
                                                       log.errors=wsim.io::error)
  }, error=function(e) {
    wsim.io::die_with_message(e$message)
  })

  wsim.io::write_vars_to_cdf(fits,
                             outfile,
                             extent=extent,
                             attrs=list(
                               list(var=NULL,key="distribution",val=distribution)
                             ))

  wsim.io::info('Wrote fits to ', outfile)
}

tryCatch(main(commandArgs(TRUE)), error=wsim.io::die_with_message)
