#!/usr/bin/env Rscript
suppressMessages({
  require(wsim.distributions)
  require(wsim.io)
})

'
Compute summary statistics from multiple observations

Usage: wsim_integrate (--stat=<stat>)... (--input=<input>)... (--output=<output>) [--attr=<attr>...]

Options:
--stat <stat>  a summary statistic (min, max, ave, sum)
--input <file> one or more input files or glob patterns
--ouput <file> output file to write integrated results
--attr <attr>  optional attribute(s) to be attached to output netCDF
'->usage

find_stat <- function(name) {
  name <- tolower(name)

  if (name == 'min')
    return(function(x) { min(x, na.rm=TRUE) })

  if (name == 'median')
    return(function(x) { median(x, na.rm=TRUE )})

  if (name == 'max')
    return(function(x) { max(x, na.rm=TRUE) })

  if (name == 'sum')
    return(function(x) { sum(x, na.rm=TRUE) })

  if (name == 'ave')
    return(function(x) { mean(x, na.rm=TRUE) })

  if (grepl('q\\d{1,2}(.\\d+)?$', name)) {
    q <- 0.01 * as.numeric(substring(name, 2))
    return(function(x) { unname(quantile(x, q, na.rm=TRUE)) })
  }

  wsim.io::die_with_message("Unknown stat ", name)
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

main <- function(raw_args) {
  args <- parse_args(usage, raw_args)

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
  first_input <- wsim.io::read_vars(inputs[[1]])
  var_attrs <- lapply(first_input$data, attributes)

  vars <- wsim.io::parse_vardef(inputs[[1]])$vars
  if (length(vars) == 0) {
    # No vars specified, so we'll take them all.
    vars <- lapply(names(first_input$data), wsim.io::make_var)
  }

  extent <- first_input$extent

  parsed_inputs <- lapply(inputs, function(input) {
    wsim.io::parse_vardef(input)
  })

  # For each var, read all files, and do processing
  # Do this to avoid loading all vars from all files into memory at once
  for (var in vars) {
    cat('Loading', toString(var), '\n')

    data <- wsim.io::read_vars_to_cube(lapply(parsed_inputs, function(input) {
      make_vardef(filename=input$filename, vars=list(var))
    }))

    integrated <- list()
    attrs <- do.call(c, lapply(args$stat, function(stat) {
      attrs_for_stat(var_attrs, var$var_out, stat)
    }))

    for (stat in args$stat) {
      stat_var <- paste0(var$var_out, '_', tolower(stat))
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
    gc()
  }
}

main(commandArgs(trailingOnly=TRUE))
#main(list('--stat=min', ' --stat=max', '--input=/tmp/T_[1-6]*.nc::data',  '--output=/tmp/T_stats_6.nc', '--attr=year=2016', '--attr=min:units=deg'))
