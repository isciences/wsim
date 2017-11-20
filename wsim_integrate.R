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
      # Update "description" and "long_name" fields with description
      # of the stat.
      return(list(
        var=stat_var,
        key=field,
        val=paste0(stat, ' of ', var_attrs[[var]][[field]])
      ))
    } else  {
      # Just pass through any other attributes.
      return(list(
        var=stat_var,
        key=field,
        val=var_attrs[[var]][[field]]
      ))
     }
  }))
}

make_stat <- function(stat=NULL, vars=NULL) {
  list(stat=stat, vars=vars)
}

parse_stat <- function(stat) {
  split_stat <- strsplit(stat, '::', fixed=TRUE)[[1]]

  if (length(split_stat) == 1) {
    return(make_stat(split_stat[1], as.character(c())))
  }

  vars_for_stat <- strsplit(split_stat[2], ',', fixed=TRUE)[[1]]
  return(make_stat(split_stat[1], vars_for_stat))
}

#' Read the unique variables (var_out) that are provided by
#' a list of inputs.
read_unique_vars <- function(parsed_inputs) {
  vars <- list()
  for (input in parsed_inputs) {
    for (var in input$vars) {
      vars[[var$var_out]] <- var$var_out
    }
  }
  vars <- unname(vars)

  return(vars)
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
    parsed <- parse_stat(stat)
    if (is.null(wsim.distributions::find_stat(parsed$stat))) {
      die_with_message("Unknown statistic", parsed$stat)
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
  extent <- first_input$extent
  dims <- dim(first_input$data[[1]])

  var_attrs <- lapply(first_input$data, attributes)

  parsed_inputs <- lapply(inputs, wsim.io::parse_vardef)

  var_names <- read_unique_vars(parsed_inputs)
  if (length(var_names) == 0) {
    # No vars specified, so we'll take all of the vars from
    # the first file (without transformation) and assume
    # they're found in all of the inputs.
    var_names <- names(first_input$data)
  }

  # For each var, read all files, and do processing
  # Do this to avoid loading all vars from all files into memory at once
  for (var_name in var_names) {
    outfile_number <- 1
    data <- provideDimnames(array(dim = c(dims, window)))

    for (i in seq_along(inputs)) {
      slice <- i %% window + 1

      if (i > window) {
        wsim.io::info('Dropping data from', dimnames(data)[[3]][slice])
      }

      # Because each input could potentially define var_out as associated with a different
      # var_in, we need to figure out the var_in associated with the given var_out
      var_to_read <- Find(function(var) {
        var$var_out == var_name
      }, parsed_inputs[[i]]$vars)

      if (is.null(var_to_read)) {
        var_to_read <- make_var(var_name)
      }

      wsim.io::info('Loading variable', var_name, 'from', parsed_inputs[[i]]$filename, '(', var_to_read, ')')

      to_read <- make_vardef(filename=parsed_inputs[[i]]$filename, vars=list(var_to_read))
      data[,,slice] <- wsim.io::read_vars(to_read)$data[[1]]
      dimnames(data)[[3]][slice] <- parsed_inputs[[i]]$filename

      if (i >= window) {
        integrated <- list()
        attrs <- list()

        for (stat in args$stat) {
          parsed_stat <- parse_stat(stat)
          if (length(parsed_stat$vars) == 0 || var_name %in% parsed_stat$vars) {
            stat_var <- paste0(var_name, '_', tolower(parsed_stat$stat))
            stat_fn <- wsim.distributions::find_stat(parsed_stat$stat)
            wsim.io::info('Computing', parsed_stat$stat, '...')

            integrated[[stat_var]] <- wsim.distributions::array_apply(data, stat_fn)

            attrs <- c(attrs, attrs_for_stat(var_attrs, var_name, parsed_stat$stat))

            wsim.io::info('done')
          }
        }

        wsim.io::info("Writing to", outfiles[outfile_number])
        wsim.io::write_vars_to_cdf(integrated, outfiles[outfile_number], extent=extent, attrs=attrs, append=TRUE)
        outfile_number <- outfile_number+1
      }

      gc()
    }
  }

  wsim.io::info("Finished writing integrated variables to", outfile)
}

if (!interactive()) {
  tryCatch(main(commandArgs(trailingOnly=TRUE)), error=wsim.io::die_with_message)
}
#main(list('--stat=min', ' --stat=max', '--input=/tmp/T_[1-6]*.nc::data',  '--output=/tmp/T_stats_6.nc', '--attr=year=2016', '--attr=min:units=deg'))
