#!/usr/bin/env Rscript
wsim.io::logging_init('wsim_merge')

'
Merge raster datasets into a single netCDF

Usage: wsim_merge (--input=<file>)... (--output=<file>) [--attr=<attr>]...
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
    wsim.io::info('Processing', input)

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
      
      # Attempt to assign any attributes that were specified with --attr
      # but did not have an assigned value
      for (i in 1:length(attrs)) {
        if (attrs[[i]]$var == var && is.null(attrs[[i]]$val)) {
          attrs[[i]]$val <- attr(v$data[[var]], attrs[[i]]$key)
        }
      }
    }
  }

  wsim.io::info('Writing to', args$output)
  wsim.io::write_vars_to_cdf(combined$data,
                             args$output,
                             extent=combined$extent,
                             attrs=attrs)
}

tryCatch(main(commandArgs(trailingOnly = TRUE)), error=wsim.io::die_with_message)
