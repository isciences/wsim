#!/usr/bin/env Rscript
wsim.io::logging_init('wsim_composite')

suppressMessages({
  require(abind)
})

'
Compute composite indicators

Usage: wsim_composite (--surplus=<file>)... (--deficit=<file>)... --both_threshold=<value> [--mask=<file>] [--clamp=<value>] --output=<file>

Options:
--surplus <file>...      One or more variables containing return periods that represent surpluses
--deficit <file>...      One or more variables containing return periods that represent deficits
--both_threshold <value> Threshold value for assigning a pixel to both surplus and deficit
--output <file>          Output file containing composite indicators
--mask <file>            Optional mask to use for computed indicators
--clamp <value>          Optional absolute value at which to clamp inputs
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

which.min.na <- function(...) {
  ifelse(all(is.na(...)), NA, which.min(...))
}

which.max.na <- function(...) {
  ifelse(all(is.na(...)), NA, which.max(...))
}

main <- function(raw_args) {
  args <- wsim.io::parse_args(usage,
                              raw_args,
                              types=list(both_threshold= 'integer',
                                         clamp= 'integer'))

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

  max_surplus_indices <- wsim.distributions::array_apply(surpluses, which.max.na)
  max_surplus_values <- vals_for_depth_index(surpluses, max_surplus_indices)
  if (!is.null(args$clamp)) {
    max_surplus_values <- clamp(max_surplus_values, -args$clamp, args$clamp)
  }

  wsim.io::info('Computed composite surplus.')

  min_deficit_indices <- wsim.distributions::array_apply(deficits, which.min.na)
  min_deficit_values <- vals_for_depth_index(deficits, min_deficit_indices)
  if (!is.null(args$clamp)) {
    min_surplus_values <- clamp(min_surplus_values, -args$clamp, args$clamp)
  }

  wsim.io::info('Computed composite deficit.')

  both_values <- ifelse(max_surplus_values > args$both_threshold & min_deficit_values < -(args$both_threshold),
                        # When above the threshold, take the largest absolute indicator
                        pmax(max_surplus_values, -min_deficit_values),
                        # When below the threshold, default to zero or NA, depending on the underlying
                        # indicators.
                        0 * max_surplus_values * min_deficit_values)

  cdf_data <- list(
    deficit= min_deficit_values*mask,
    deficit_cause= min_deficit_indices*mask,

    surplus= max_surplus_values*mask,
    surplus_cause= max_surplus_indices*mask,

    both= both_values*mask
  )

  cdf_attrs <- list(
    list(var="deficit", key="long_name", val="Composite Deficit Index"),

    list(var="deficit_cause", key="long_name", val="Cause of Deficit"),
    list(var="deficit_cause", key="flag_values", val=1:dim(deficits)[3], prec="byte"),
    list(var="deficit_cause", key="flag_meanings", val=paste(dimnames(deficits)[[3]], collapse=" "), prec="text"),

    list(var="surplus", key="long_name", val="Composite Surplus Index"),

    list(var="surplus_cause", key="long_name", val="Cause of Surplus"),
    list(var="surplus_cause", key="flag_values", val=1:dim(surpluses)[3], prec="byte"),
    list(var="surplus_cause", key="flag_meanings", val=paste(dimnames(surpluses)[[3]], collapse=" "), prec="text"),

    list(var="both", key="long_name", val="Composite Combined Surplus & Deficit Index"),
    list(var="both", key="threshold", val=args$both_threshold)
  )

  wsim.io::write_vars_to_cdf(cdf_data,
                             outfile,
                             extent= attr(deficits, 'extent'),
                             attrs= cdf_attrs,
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
