#!/usr/bin/env Rscript
suppressMessages({
  require(docopt)
  require(wsim.distributions)
  require(wsim.io)
  require(raster)
  require(ncdf4)
})

'
Fit statistical distributions.

Usage: wsim_fit (--distribution=<dist>) (--input=<file>)... (--output=<file>)

--distribution the statistical distribution to be fit
'->usage

args <- tryCatch(docopt(usage), error=function(e) {
  write('Error parsing args.', stderr())
  write(usage, stdout())
  quit(status=1)
})

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

writeFit2Cdf(fits, outfile, attrs=list(distribution=distribution))
