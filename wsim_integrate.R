#!/usr/bin/env Rscript

# Copyright (c) 2018-2019 ISciences, LLC.
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

Usage: wsim_integrate (--stat=<stat>)... (--input=<input>)... (--output=<output>)... [--weights=<weights>] [--window=<window>] [--attr=<attr>...] [--keepvarnames]

Options:
--stat <stat>       a summary statistic (min, max, ave, sum). By default, the statistic is computed
                    for all input variables. This can be restricted by providing a list of variables,
                    such as --stat "max::flow,temp"
--input <file>      one or more input files or glob patterns
--weights <w>       a comma-separated list of weights for each input
--output <file>     output file(s) to write integrated results
--window <window>   size of rolling window to use for integration (e.g. 6 files)
--attr <attr>       optional attribute(s) to be attached to output netCDF
--keepvarnames      do not append name of stat to output variable names
'->usage

attrs_for_stat <- function(var_attrs, var, stat, stat_var) {
  # Autogenerate metadata

  Filter(Negate(is.null), lapply(names(var_attrs[[var]]), function(field) {
    # Don't pass "dim" R attr, or _FillValue/missing_data netCDF attr through
    if (field %in% c('dim', 'dimnames', '_FillValue', 'missing_data', 'missing_value')) {
      return(NULL)
    }

    # Don't pass through scaling attributes, since we will transform packed
    # integer variables into floating point variables
    if (field %in% c('scale_factor', 'add_offset')) {
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

accepts_weights <- function(stat_name) {
  startsWith(stat_name, 'weighted_')
}

validate_stats <- function(parsed_stats, have_weights) {
  for (stat in parsed_stats) {
    stat_name <- stat$stat

    if (is.null(wsim.distributions::find_stat(stat_name))) {
      die_with_message("Unknown statistic", stat_name)
    }

    if (accepts_weights(stat_name) && !have_weights) {
      stop('No weights provided for stat', stat_name)
    }
  }
}

to_list <- function(dimname, dimval) {
  if (is.null(dimname))
    return(NULL)

  ret <- list()
  ret[[dimname]] <- dimval
  return(ret)
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
  output_attrs <- lapply(args$attr, wsim.io::parse_attr)

  weights <- NULL
  if (!is.null(args$weights)) {
    weights <- sapply(strsplit(args$weights, ',', fixed=TRUE), as.numeric)
  }

  # Probe for non-trivial extra dimensions
  extra_dims_found <- wsim.io::read_dimension_values(inputs[[1]],
                                                     exclude.dims=c('lat', 'lon', 'id', 'latitude', 'longitude'),
                                                     exclude.degenerate=TRUE)

  if (length(extra_dims_found) == 0) {
    extra_dim_name <- NULL
    extra_dim_vals <- list(NULL)
  } else if (length(extra_dims_found) == 1) {
    extra_dim_name <- names(extra_dims_found)[1]
    extra_dim_vals <- extra_dims_found[[1]]
    wsim.io::infof("Discovered dimension %s with %d values.", extra_dim_name, length(extra_dim_vals))
  } else  {
    stop("Don't know how to handle more than one extra dimension. Found " + paste(names(extra_dims_found), collapse=', '))
  }

  first_input <- wsim.io::read_vars(inputs[[1]], extra_dims=to_list(extra_dim_name, extra_dim_vals[1]))
  extent <- first_input$extent
  ids <- first_input$ids
  dims <- dim(first_input$data[[1]])
  var_attrs <- lapply(first_input$data, attributes)

  if (length(dims) == 1) {
    dims <- c(1, dims)
  }

  # Validate configuration
  validate_stats(parsed_stats, !is.null(weights))

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
    die_with_message("Given", length(inputs), "inputs and window size",
                     window, ", expected ", frames, "output files",
                     "but got", length(outfiles), ".")
  }

  if (!is.null(weights) && length(weights) != length(inputs)) {
    die_with_message(sprintf('Unequal numbers of inputs (%d) and weights (%d) provided.',
                             length(inputs), length(weights)))
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

  for (z in seq_along(extra_dim_vals)) {
    outfile_number <- 1

    data <- list()
    for (var_name in var_names) {
      # Create an empty array to hold <window> time slices of data
      data[[var_name]] <- provideDimnames(array(dim = c(dims, window)))
    }
    # Create an empty vector to store weights for <window>
    data_weights <- rep.int(1.0, 5)

    for (i in seq_along(inputs)) {
      slice <- i %% window + 1 # We recycle space in the array. This is the index we should load into.

      if (i > window) {
        source_file_for_data_to_overwrite <- dimnames(data[[1]])[[3]][slice]
        wsim.io::infof('Dropping data from %s', source_file_for_data_to_overwrite)
      }

      vars_to_read <- lapply(var_names, function(var_name) get_var_to_read(var_name, i))
      wsim.io::infof('Loading variables %s from %s (from %s)', paste(var_names, collapse=', '), parsed_inputs[[i]]$filename, paste(sapply(vars_to_read, function(v) v$var_in), collapse=', '))
      dimnames(data[[1]])[[3]][slice] <- parsed_inputs[[i]]$filename

      data_slice <- wsim.io::read_vars(make_vardef(filename=parsed_inputs[[i]]$filename,
                                                   vars=vars_to_read),
                                       expect.extent=extent,
                                       expect.ids=ids,
                                       extra_dims=to_list(extra_dim_name, extra_dim_vals[z]))$data

      for (var_name in var_names) {
        data[[var_name]][,,slice] <- as.matrix(data_slice[[var_name]])
      }

      if (!is.null(weights)) {
        data_weights[slice] <- weights[i]
      }

      if (i >= window) {
        integrated <- list()
        attrs <- output_attrs

        for (stat in parsed_stats) {
          for (var_name in var_names) {
            if (length(stat$vars) == 0 || var_name %in% stat$vars) {
              if (args$keepvarnames) {
                stat_var <- var_name
              } else {
                stat_var <- paste0(var_name, '_', tolower(stat$stat))
              }
              stat_fn <- wsim.distributions::find_stat(stat$stat)
              wsim.io::infof('Computing %s', stat_var)

              if (accepts_weights(stat$stat)) {
                integrated[[stat_var]] <- stat_fn(data[[var_name]], data_weights)
              } else {
                integrated[[stat_var]] <- stat_fn(data[[var_name]])
              }

              attrs <- c(attrs, attrs_for_stat(var_attrs, var_name, stat$stat, stat_var))
            }
          }
        }

        if (is.null(extra_dim_name)) {
          wsim.io::infof("Writing to %s", outfiles[outfile_number])
        } else {
          wsim.io::infof("Writing to %s (%s)", outfiles[outfile_number], extra_dim_vals[z])
        }
        wsim.io::write_vars_to_cdf(integrated,
                                   outfiles[outfile_number],
                                   extent=extent,
                                   ids=ids,
                                   attrs=attrs,
                                   prec='single',
                                   extra_dims=to_list(extra_dim_name, extra_dim_vals),
                                   write_slice=to_list(extra_dim_name, extra_dim_vals[z]),
                                   append=TRUE)
        outfile_number <- outfile_number+1
      }

      gc()
    }
  }

  wsim.io::infof("Finished writing integrated variables to %s", outfile)
}

#tryCatch(
  main(commandArgs(trailingOnly=TRUE))
#,error=wsim.io::die_with_message)
