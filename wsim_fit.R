#!/usr/bin/env Rscript
wsim.io::logging_init('wsim_fit')

'
Fit statistical distributions.

Usage: wsim_fit (--distribution=<dist>) (--input=<file>)... (--output=<file>) [--cores=<num>] [--attr=<attr>]...

--distribution <dist> the statistical distribution to be fit
--input <file>        Files to read observations
--output <file>       Output netCDF file with distribution fit parameters
--cores <num>         Number of CPU cores to use [default: 1]
--attr <attr>         Optional attribute(s) to write to output netCDF file
'->usage

main <- function(raw_args) {
  args <- wsim.io::parse_args(usage, raw_args, types=list(cores="integer"))

  outfile <- args$output
  if (!wsim.io::can_write(outfile)) {
    wsim.io::die_with_message("Cannot open", outfile, "for writing.")
  }

  if (args$cores > 1) {
    c1 <- parallel::makeCluster(args$cores)
    parallel::setDefaultCluster(c1)
  }

  output_attrs <- lapply(args$attr, wsim.io::parse_attr)

  expanded_inputs <- wsim.io::expand_inputs(args$input)
  wsim.io::info('Preparing to load vars from', length(expanded_inputs), "files.")
  inputs_stacked <- wsim.io::read_vars_to_cube(expanded_inputs)
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
                             attrs=c(
                               output_attrs,
                               list(
                                 list(var=NULL,key="distribution",val=distribution)
                             )))

  wsim.io::info('Wrote fits to', outfile)
}

tryCatch(main(commandArgs(TRUE)), error=wsim.io::die_with_message)
