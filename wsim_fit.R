#!/usr/bin/env Rscript
suppressMessages({
  require(docopt)
  require(wsim.distributions)
  require(wsim.io)
  require(raster)
  require(ncdf4)
})

die <- function(...) {
    write(paste0(list(...), collapse=""), stderr())
    quit(save='no', status=1, runLast=FALSE)
}

can_write <- function(filename) {
  if (file.exists(filename)) {
    # File exists, can we write to it?
    return(unname(file.access(filename, mode=2)) == 0)
  } else {
    tryCatch({
      file.create(filename)
      while(!file.exists(filename)) {
        Sys.sleep(0.005)
      }
      file.remove(filename)
      return(TRUE);
    }, error=function() {
      print('problem')
      return(FALSE);
    })
  }
}

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
  die("Cannot open ", outfile, " for writing.")
}

inputs <- stack(readInputs(args))

distribution <- tolower(args$distribution)

if (distribution == 'gev') {
  fits <- fitGEV(inputs)
} else {
  die(distribution, " is not a supported statistical distribution.")
}

writeFit2Cdf(fits, outfile, attrs=list(distribution=distribution))
