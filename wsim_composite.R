#!/usr/bin/env Rscript

# Copyright (c) 2018-2020 ISciences, LLC.
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

wsim.io::logging_init('wsim_composite')

suppressMessages({
  require(Rcpp)
})

'
Compute composite indicators

Usage: wsim_composite (--surplus=<file>)... (--deficit=<file>)... --both_threshold=<value> [--mask=<file>] [--clamp=<value>] [--causes_from=<file>] --output=<file> [--attr=<attr>]...

Options:
--surplus <file>...      One or more variables containing return periods that represent surpluses
--deficit <file>...      One or more variables containing return periods that represent deficits
--both_threshold <value> Threshold value for assigning a pixel to both surplus and deficit
--output <file>          Output file containing composite indicators
--mask <file>            Optional mask to use for computed indicators
--clamp <value>          Optional absolute value at which to clamp inputs
--causes_from <file>     Optionally copy surplus_cause and deficit_cause from file instead of computing from inputs
--attr <attr>            Optional attributes to attach to output netCDF(s)
'->usage

clamp <- function(vals, minval, maxval) {
  pmax(pmin(vals, maxval), minval)
}

vals_for_depth_index <- function(arr, depth) {
  # Susbset the 3D array by providing a matrix of (row, col, level) triplets
  array(arr[cbind(as.vector(row(depth)),
                  as.vector(col(depth)),
                  as.vector(depth))],
        dim=dim(depth))
}

main <- function(raw_args) {
  args <- wsim.io::parse_args(usage,
                              raw_args,
                              types=list(both_threshold= 'integer',
                                         clamp= 'integer'))
  
  attrs <- lapply(args$attr, wsim.io::parse_attr)

  if (is.null(args$deficit)) {
    wsim.io::die_with_message("Must supply at least one deficit indicator.")
  }

  if (is.null(args$surplus)) {
    wsim.io::die_with_message("Must supply at least one surplus indicator.")
  }

  outfile <- args$output
  if (!wsim.io::can_write(outfile)) {
    wsim.io::die_with_message("Cannot open ", outfile, " for writing.")
  }

  surpluses <- wsim.io::read_vars_to_cube(args$surplus)
  wsim.io::info('Read surplus values:', paste(dimnames(surpluses)[[3]], collapse=", "))

  deficits <- wsim.io::read_vars_to_cube(args$deficit)
  wsim.io::info('Read deficit values:', paste(dimnames(deficits)[[3]], collapse=", "))

  if (is.null(args$mask)) {
    mask <- 1
  } else {
    mask_data <- wsim.io::read_vars(args$mask)$data[[1]]
    mask <- ifelse(!is.na(mask_data), 1, NA)
  }

  max_surplus_indices <- wsim.distributions::stack_which_max(surpluses)
  max_surplus_values <- vals_for_depth_index(surpluses, max_surplus_indices)
  if (!is.null(args$clamp)) {
    max_surplus_values <- clamp(max_surplus_values, -args$clamp, args$clamp)
  }

  wsim.io::info('Computed composite surplus.')

  min_deficit_indices <- wsim.distributions::stack_which_min(deficits)
  min_deficit_values <- vals_for_depth_index(deficits, min_deficit_indices)
  if (!is.null(args$clamp)) {
    min_deficit_values <- clamp(min_deficit_values, -args$clamp, args$clamp)
  }

  wsim.io::info('Computed composite deficit.')

  both_values <- ifelse(max_surplus_values > args$both_threshold & min_deficit_values < -(args$both_threshold),
                        # When above the threshold, take the largest absolute indicator
                        pmax(max_surplus_values, -min_deficit_values),
                        # When below the threshold, default to zero or NA, depending on the underlying
                        # indicators.
                        0 * max_surplus_values * min_deficit_values)

  if (is.null(args$causes_from)) {
    # Compute causes based on inputs
    deficit_cause <- min_deficit_indices * mask
    deficit_cause_flags <- seq_len(dim(deficits)[3])
    deficit_cause_flag_meanings <- paste(dimnames(deficits)[[3]], collapse=" ")

    surplus_cause <- max_surplus_indices * mask
    surplus_cause_flags <- seq_len(dim(surpluses)[3])
    surplus_cause_flag_meanings <- paste(dimnames(surpluses)[[3]], collapse=" ")
  } else {
    # Copy causes from another file (used for adjusted composites)
    wsim.io::infof('Reading surplus and deficit causes from %s', args$causes_from)

    causes <- wsim.io::read_vars(sprintf('%s::deficit_cause,surplus_cause', args$causes_from))
    deficit_cause <- causes$data$deficit_cause * mask
    deficit_cause_flags <- attr(causes$data$deficit_cause, 'flag_values')
    deficit_cause_flag_meanings <- attr(causes$data$deficit_cause, 'flag_meanings')

    surplus_cause <- causes$data$surplus_cause * mask
    surplus_cause_flags <- attr(causes$data$surplus_cause, 'flag_values')
    surplus_cause_flag_meanings <- attr(causes$data$surplus_cause, 'flag_meanings')
  }

  cdf_data <- list(
    deficit= min_deficit_values*mask,
    deficit_cause= deficit_cause,

    surplus= max_surplus_values*mask,
    surplus_cause= surplus_cause,

    both= both_values*mask
  )

  attrs <- c(attrs, list(
    list(var="deficit", key="long_name", val="Composite Deficit Index"),

    list(var="deficit_cause", key="long_name", val="Cause of Deficit"),
    list(var="deficit_cause", key="flag_values", val=deficit_cause_flags, prec="byte"),
    list(var="deficit_cause", key="flag_meanings", val=deficit_cause_flag_meanings, prec="text"),

    list(var="surplus", key="long_name", val="Composite Surplus Index"),

    list(var="surplus_cause", key="long_name", val="Cause of Surplus"),
    list(var="surplus_cause", key="flag_values", val=surplus_cause_flags, prec="byte"),
    list(var="surplus_cause", key="flag_meanings", val=surplus_cause_flag_meanings, prec="text"),

    list(var="both", key="long_name", val="Composite Combined Surplus & Deficit Index"),
    list(var="both", key="threshold", val=args$both_threshold)
  ))

  wsim.io::write_vars_to_cdf(cdf_data,
                             outfile,
                             extent= attr(deficits, 'extent'),
                             attrs= attrs,
                             prec=list(
                               deficit= "float",
                               deficit_cause= "byte",
                               surplus= "float",
                               surplus_cause= "byte",
                               both= "float"
                             ))

  wsim.io::info("Wrote composite indicators to", outfile)
}

tryCatch(main(commandArgs(trailingOnly=TRUE)), error=wsim.io::die_with_message)
