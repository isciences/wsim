#!/usr/bin/env Rscript
suppressMessages({
  require(wsim.distributions)
  require(wsim.io)
  require(raster)
})

'
Fit statistical distributions.

Usage: wsim_fit (--distribution=<dist>) (--input=<file>)... (--output=<file>)

--distribution the statistical distribution to be fit
'->usage

args <- parse_args(usage)

outfile <- args$output
if (!can_write(outfile)) {
  die_with_message("Cannot open ", outfile, " for writing.")
}

inputs <- stack(expand_inputs(args$input))

distribution <- tolower(args$distribution)

if (distribution == 'gev') {
  fits <- fitGEV(inputs)
} else {
  die_with_message(distribution, " is not a supported statistical distribution.")
}

write_stack_to_cdf(fits, outfile, attrs=list(distribution=distribution))
