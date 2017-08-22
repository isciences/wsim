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

readInputs <- function(args) {
  inputs <- NULL;
  for (arg in args$input) {
    globbed <- Sys.glob(arg)

    if (length(globbed) == 0) {
      die("No input files found matching pattern: ", arg)
    }
    inputs <- c(inputs, globbed)
  }

  return(inputs)
}

outfile <- args$output
if (!can_write(outfile)) {
  die_with_message("Cannot open ", outfile, " for writing.")
}

inputs <- stack(readInputs(args))

distribution <- tolower(args$distribution)

if (distribution == 'gev') {
  fits <- fitGEV(inputs)
} else {
  die_with_message(distribution, " is not a supported statistical distribution.")
}

writeFit2Cdf(fits, outfile, attrs=list(distribution=distribution))
