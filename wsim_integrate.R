#!/usr/bin/env Rscript
suppressMessages({
  require(wsim.distributions)
  require(wsim.io)
  require(raster)
})

'
Compute summary statistics from multiple observations

Usage: wsim_integrate (--stat=<stat>)... (--input=<input>)... (--output=<output>) [--attr=<attr>...]

--stat a summary statistic (min, max, ave, sum)
--input one or more input files or glob pattern
--ouput output file to write integrated results
--attr optional attribute(s) to be attached to output NetCDF
'->usage

find_stat <- function(name) {
  switch(tolower(name),
         min= function(x) { min(x,  na.rm=TRUE) },
         max= function(x) { max(x,  na.rm=TRUE) },
         sum= function(x) { sum(x,  na.rm=TRUE) },
         ave= function(x) { mean(x, na.rm=TRUE) },
         NULL
  )
}

main <- function() {
  args <- parse_args(usage)

  outfile <- args$output
  if (!can_write(outfile)) {
    die_with_message("Cannot open ", outfile, " for writing.")
  }

  inputs <- stack(expand_inputs(args$input))
  stat_fns <- lapply(args$stat, function(stat) {
    stat_fn <- find_stat(stat)
    if (is.null(stat_fn)) {
      die_with_message("Unknown statistic", stat)
    }
    return(stat_fn)
  })

  integrated <- rsapply(inputs, function(vals) {
    if (all(is.na(vals))) {
      # Return early to avoid generating a "no non-NA values" warning from
      # our stat function
      return(rep.int(NA, length(stat_fns)))
    }

    results <- vector(mode="numeric", length(stat_fns))

    for (i in 1:length(stat_fns)) {
      results[i] <- stat_fns[[i]](vals)
    }

    return(results)
  })

  if (class(integrated) == "RasterLayer") {
    integrated <- stack(integrated)
  }
  names(integrated) <- args$stat

  write_stack_to_cdf(integrated, outfile, attrs=lapply(args$attr, parse_attr))
}

main()
