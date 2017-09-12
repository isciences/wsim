#!/usr/bin/env Rscript
suppressMessages({
  require(wsim.distributions)
  require(wsim.io)
  require(abind)
})

'
Compute summary statistics from multiple observations

Usage: wsim_integrate (--stat=<stat>)... (--input=<input>)... (--output=<output>) [--attr=<attr>...]

Options:
--stat <stat> a summary statistic (min, max, ave, sum)
--input <file> one or more input files or glob pattern
--ouput <file> output file to write integrated results
--attr <attr> optional attribute(s) to be attached to output NetCDF
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

attrs_for_stat <- function(var_attrs, var, stat) {
  # Autogenerate metadata
  stat_var <- paste0(var, '_', tolower(stat))

  Filter(Negate(is.null), lapply(names(var_attrs[[var]]), function(field) {
    if (field %in% c('dim')) {
      return(NULL)
    }
    if (field %in% c('description', 'long_name')) {
      return(list(
        var=stat_var,
        key=field,
        val=paste0(stat, ' of ', var_attrs[[var]][[field]])
      ))
    } else  {
      return(list(
        var=stat_var,
        key=field,
        val=var_attrs[[var]][[field]]
      ))
     }
  }))
}

main <- function() {
  args <- parse_args(usage)

  outfile <- args$output
  if (!can_write(outfile)) {
    die_with_message("Cannot open ", outfile, " for writing.")
  }

  for (stat in args$stat) {
    if (is.null(find_stat(stat))) {
      die_with_message("Unknown statistic", stat)
    }
  }

  inputs <- expand_inputs(args$input)

  # Get a list of vars. For now, all vars will be processed.
  first_input <- wsim.io::read_vars_from_cdf(inputs[[1]])
  vars <- names(first_input$data)
  var_attrs <- lapply(first_input$data, attributes)
  extent <- first_input$extent

  # For each var, read all files, and do processing
  # Do this to avoid loading all vars from all files into memory at once
  for (var in vars) {
    cat('Loading', var, '\n')
    data <- abind(lapply(inputs, function(fname) {
      wsim.io::read_vars_from_cdf(fname, vars=list(var))$data[[var]]
    }), along=3)

    integrated <- list()
    attrs <- do.call(c, lapply(args$stat, function(stat) {
      attrs_for_stat(var_attrs, var, stat)
    }))

    for (stat in args$stat) {
      stat_var <- paste0(var, '_', tolower(stat))
      stat_fn <- find_stat(stat)
      cat('Computing', stat_var, '...')

      integrated[[stat_var]] <- wsim.distributions::array_apply(data, function(vals) {
        if (all(is.na(vals))) {
          return(as.numeric(NA))
        }

        return(stat_fn(vals))
      })
      cat('done.\n')
    }

    wsim.io::write_vars_to_cdf(integrated, outfile, extent=extent, attrs=attrs, append=TRUE)
  }
}

main()
