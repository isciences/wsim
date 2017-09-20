#!/usr/bin/env Rscript

'
Merge raster datasets into a single netCDF

Usage: wsim_fit (--input=<file>)... (--output=<file>) [--attr=<attr>]
'->usage

main <- function(raw_args) {
  args <- wsim.io::parse_args(usage, raw_args)

  inputs <- wsim.io::expand_inputs(args$input)

  attrs <- lapply(args$attr, wsim.io::parse_attr)

  combined <- list(
    attrs= list(),
    extent= NULL,
    data= list()
  )

  for (input in inputs) {
    cat('Processing', input, '\n')

    v <- wsim.io::read_vars(input)

    if (is.null(combined$extent)) {
      combined$extent <- v$extent
    } else {
      stopifnot(all(combined$extent == v$extent))
    }

    for (var in names(v$data)) {
      if (var %in% names(combined$data)) {
        wsim.io::die_with_message("Multiple definitions of variable ", var)
      }

      combined$data[[var]] <- v$data[[var]]
    }
  }

  cat('Writing to', args$output, '\n')
  wsim.io::write_vars_to_cdf(combined$data,
                             args$output,
                             extent=combined$extent,
                             attrs=attrs)
}

main(commandArgs(trailingOnly = TRUE))