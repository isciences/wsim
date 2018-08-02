#!/usr/bin/env Rscript

# Copyright (c) 2018 ISciences, LLC.
# All rights reserved.
#
# WSIM is licensed under the Apache License, Version 2.0 (the "License").
# You may not use this file except in compliance with the License. You may
# obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0.
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

wsim.io::logging_init('wsim_integrate')

suppressMessages({
  require(Rcpp)
  require(wsim.distributions)
  require(wsim.io)
})

'
Compute summary statistics from multiple observations

Usage: wsim_integrate (--stat=<stat>)... (--input=<input>)... (--output=<output>)... [--window=<window>] [--attr=<attr>...] [--keepvarnames]

Options:
--stat <stat>       a summary statistic (min, max, ave, sum). By default, the statistic is computed
                    for all input variables. This can be restricted by providing a list of variables,
                    such as --stat "max::flow,temp"
--input <file>      one or more input files or glob patterns
--output <file>     output file(s) to write integrated results
--window <window>   size of rolling window to use for integration (e.g. 6 files)
--attr <attr>       optional attribute(s) to be attached to output netCDF
--keepvarnames      do not append name of stat to output variable names
'->usage

attrs_for_stat <- function(var_attrs, var, stat, stat_var) {
  # Autogenerate metadata

  Filter(Negate(is.null), lapply(names(var_attrs[[var]]), function(field) {
    # Don't pass "dim" R attr, or _FillValue/missing_data netCDF attr through
    if (field %in% c('dim', '_FillValue', 'missing_data')) {
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
    } else {
      # Just pass through any other attributes
      return(list(
        var=stat_var,
        key=field,
        val=var_attrs[[var]][[field]]
      ))
     }
  }))
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

validate_stats <- function(parsed_stats) {
  for (stat in parsed_stats) {
    if (is.null(wsim.distributions::find_stat(stat$stat))) {
      die_with_message("Unknown statistic", stat$stat)
    }
  }
}

main <- function(raw_args) {
  args <- parse_args(usage, raw_args, list(window="integer"))

  outfiles <- do.call(c, lapply(args$output, wsim.io::expand_dates))
  for (outfile in outfiles) {
    if (!can_write(outfile)) {
      die_with_message("Cannot open", outfile, "for writing.")
    }
  }

  # Read/parse arguments
  inputs <- expand_inputs(args$input)
  parsed_stats <- lapply(args$stat, parse_stat)
  parsed_inputs <- lapply(inputs, wsim.io::parse_vardef)

  first_input <- wsim.io::read_vars(inputs[[1]])
  extent <- first_input$extent
  ids <- first_input$ids
  dims <- dim(first_input$data[[1]])
  var_attrs <- lapply(first_input$data, attributes)

  # Validate configuration
  validate_stats(parsed_stats)

  if (args$keepvarnames && length(args$stat) > 1) {
    die_with_message("Can't keep original variable names if > 1 stat is being computed.")
  }

  if (is.null(args$window)) {
    window <- length(inputs)
    frames <- 1
  } else {
    window <- args$window
    frames <- length(inputs) - window + 1
  }

  if (window > length(inputs)) {
    die_with_message("Cannot compute using window size of", window,
                     "with only ", length(inputs), "input files.")
  }

  if (length(outfiles) != frames) {
    die_with_message("Given", length(inputs), "inputs and window size ",
                     window, ", expected ", frames, "output files",
                     "but got", length(outfiles), ".")
  }

  get_var_to_read <- function(var_name, i) {
    # Because each input could potentially define var_out as associated with a different
    # var_in, we need to figure out the var_in associated with the given var_out for the
    # ith input
    var_to_read <- Find(function(var) {
      var$var_out == var_name
    }, parsed_inputs[[i]]$vars)

    if (is.null(var_to_read)) {
      var_to_read <- make_var(var_name)
    }

    return(var_to_read)
  }

  var_names <- read_unique_vars(parsed_inputs)
  if (length(var_names) == 0) {
    # No vars specified, so we'll take all of the vars from
    # the first file (without transformation) and assume
    # they're found in all of the inputs.
    var_names <- names(first_input$data)
  }

  outfile_number <- 1

  data <- list()
  for (var_name in var_names) {
    # Create an empty array to hold <window> time slices of data
    data[[var_name]] <- provideDimnames(array(dim = c(dims, window)))
  }

  for (i in seq_along(inputs)) {
    slice <- i %% window + 1 # We recycle space in the array. This is the index we should load into.

    if (i > window) {
      source_file_for_data_to_overwrite <- dimnames(data[[1]])[[3]][slice]
      wsim.io::info('Dropping data from', source_file_for_data_to_overwrite)
    }

    vars_to_read <- lapply(var_names, function(var_name) get_var_to_read(var_name, i))
    wsim.io::info('Loading variables', var_names, 'from', parsed_inputs[[i]]$filename, '( from', sapply(vars_to_read, function(v) v$var_in), ')')
    dimnames(data[[1]])[[3]][slice] <- parsed_inputs[[i]]$filename

    data_slice <- wsim.io::read_vars(make_vardef(filename=parsed_inputs[[i]]$filename,
                                                 vars=vars_to_read),
                                     expect.extent=extent,
                                     expect.ids=ids)$data

    for (var_name in var_names) {
      data[[var_name]][,,slice] <- data_slice[[var_name]]
    }

    if (i >= window) {
      integrated <- list()
      attrs <- list()

      for (stat in parsed_stats) {
        for (var_name in var_names) {
          if (length(stat$vars) == 0 || var_name %in% stat$vars) {
            if (args$keepvarnames) {
              stat_var <- var_name
            } else {
              stat_var <- paste0(var_name, '_', tolower(stat$stat))
            }
            stat_fn <- wsim.distributions::find_stat(stat$stat)
            wsim.io::info('Computing', stat_var, '...')

            integrated[[stat_var]] <- stat_fn(data[[var_name]])

            attrs <- c(attrs, attrs_for_stat(var_attrs, var_name, stat$stat, stat_var))

            wsim.io::info('done')
          }
        }
      }

      wsim.io::info("Writing to", outfiles[outfile_number])
      wsim.io::write_vars_to_cdf(integrated, outfiles[outfile_number], extent=extent, ids=ids, attrs=attrs, prec='single', append=TRUE)
      outfile_number <- outfile_number+1
    }

    gc()
  }

  wsim.io::info("Finished writing integrated variables to", outfile)
}

tryCatch(
  main(commandArgs(trailingOnly=TRUE))
  ,error=wsim.io::die_with_message)
