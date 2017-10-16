#!/usr/bin/env Rscript
wsim.io::logging_init('wsim_integrate')

suppressMessages({
  require(Rcpp)
  require(wsim.distributions)
  require(wsim.io)
})

'
Compute summary statistics from multiple observations

Usage: wsim_integrate (--stat=<stat>)... (--input=<input>)... (--output=<output>)... [--window=<window>] [--attr=<attr>...]

Options:
--stat <stat>     a summary statistic (min, max, ave, sum)
--input <file>    one or more input files or glob patterns
--ouput <file>    output file(s) to write integrated results
--window <window> size of rolling window to use for integration (e.g. 6 files)
--attr <attr>     optional attribute(s) to be attached to output netCDF
'->usage

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
  args <- parse_args(usage, raw_args, list(window="integer"))

  outfiles <- args$output
  for (outfile in outfiles) {
    if (!can_write(outfile)) {
      die_with_message("Cannot open ", outfile, " for writing.")
    }
  }

  for (stat in args$stat) {
    if (is.null(wsim.distributions::find_stat(stat))) {
      die_with_message("Unknown statistic", stat)
    }
  }

  inputs <- expand_inputs(args$input)

  if (is.null(args$window)) {
    window <- length(inputs)
    frames <- 1
  } else {
    window <- args$window
    frames <- length(inputs) - window + 1
  }

  if (window > length(inputs)) {
    die_with_message("Cannot compute using window size of ", window,
                     " with only ", length(inputs), " input files.")
  }

  if (length(outfiles) != frames) {
    die_with_message("Given ", length(inputs), " inputs and window size ",
                     window, ", expected ", frames, " output files ",
                     "but got ", length(outfiles), ".")
  }

  first_input <- wsim.io::read_vars(inputs[[1]])
  var_attrs <- lapply(first_input$data, attributes)

  vars <- wsim.io::parse_vardef(inputs[[1]])$vars
  if (length(vars) == 0) {
    # No vars specified, so we'll take them all.
    vars <- lapply(names(first_input$data), wsim.io::make_var)
  }

  extent <- first_input$extent
  dims <- dim(first_input$data[[1]])

  parsed_inputs <- lapply(inputs, function(input) {
    wsim.io::parse_vardef(input)
  })

  # For each var, read all files, and do processing
  # Do this to avoid loading all vars from all files into memory at once
  for (var in vars) {

    j <- 1
    data <- provideDimnames(array(dim = c(dims, window)))

    for (i in 1:length(inputs)) {
      slice <- i %% window + 1

      if (i > window) {
        wsim.io::info('Dropping data from', dimnames(data)[[3]][slice])
      }
      wsim.io::info('Loading variable', toString(var), 'from', parsed_inputs[[i]]$filename)

      data[,,slice] <- wsim.io::read_vars(make_vardef(filename=parsed_inputs[[i]]$filename, vars=list(var)))$data[[1]]
      dimnames(data)[[3]][slice] <- parsed_inputs[[i]]$filename

      if (i >= window) {
        integrated <- list()
        attrs <- do.call(c, lapply(args$stat, function(stat) {
          attrs_for_stat(var_attrs, var$var_out, stat)
        }))

        for (stat in args$stat) {
          stat_var <- paste0(var$var_out, '_', tolower(stat))
          stat_fn <- wsim.distributions::find_stat(stat)
          wsim.io::info('Computing', stat_var, '...')

          integrated[[stat_var]] <- wsim.distributions::array_apply(data, stat_fn)

          wsim.io::info('done')
        }

        wsim.io::info("Writing to", outfiles[j])
        wsim.io::write_vars_to_cdf(integrated, outfiles[j], extent=extent, attrs=attrs, append=TRUE)
        j <- j+1
      }

      gc()
    }
  }

  wsim.io::info("Finished writing integrated variables to", outfile)
}

main(commandArgs(trailingOnly=TRUE))
#main(list('--stat=min', ' --stat=max', '--input=/tmp/T_[1-6]*.nc::data',  '--output=/tmp/T_stats_6.nc', '--attr=year=2016', '--attr=min:units=deg'))
