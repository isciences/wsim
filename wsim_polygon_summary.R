#!/usr/bin/env Rscript

# Copyright (c) 2022 ISciences, LLC.
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

wsim.io::logging_init('wsim_polygon_summary')

suppressPackageStartupMessages({
  library(exactextractr)
  library(dplyr)
})

'
Summarize gridded values within a polygon

Usage: wsim_polygon_summary.R --values=<file>... --weights=<file> --breaks=<values> --polygons=<file> --append-cols=<value> --output=<value>

Options:
--values <file>        Values to be summarized, such as composite anomalies
--weights <file>       Weights to use in the summary, such as population density
--breaks <values>      Comma-separated list of value thresholds
--polygons <file>      Polygons over which values should be summarized
--append-cols <values> Comma-separated list of field names from polygons to include in output
--output <file>        Output CSV file
'->usage

main <- function(raw_args) {
  args <- wsim.io::parse_args(usage, raw_args)

  read_vars_to_rast <- function(vardefs) {
    terra::rast(lapply(vardefs, function(vardef) {
      parsed <- wsim.io::parse_vardef(vardef)

      # special case: single variable, no transforms
      # avoid reading values into memory
      if (length(parsed$vars) == 1) {
        v <- parsed$vars[[1]]
        if (length(v$transforms) == 0) {
          if (length(grep('^\\d+$', v$var_in)) > 0) {
            lyr <- as.integer(v$var_in)
          } else {
            lyr <- v$var_in
          }
          r <- terra::rast(parsed$filename, lyrs = lyr)
          names(r) <- v$var_out
          return(r)
        }
      }

      # general case: read into memory
      x <- wsim.io::read_vars(vardef)
      ex <- terra::ext(x$extent)
      r <- terra::rast(lapply(x$data, terra::rast, crs = 'EPSG:4326', extent = ex))
      names(r) <- names(x$data)
      return(r)
    }))
  }

  # Read all input values into single SpatRaster. Use the wsim.io machinery,
  # which allows us to do minor transformations if needed, such as flipping
  # the sign on deficit anomalies.
  values <- read_vars_to_rast(args$values)
  wsim.io::infof('Read values: %s', paste(names(values), collapse = ', '))

  # Reads weights directly as a terra SpatRaster. We can't go through wsim.io
  # because the weighting rasters that we use in practice may not fit into memory.
  weights <- read_vars_to_rast(args$weights)
  wsim.io::infof('Read weights: %s', paste(names(weights), collapse = ', '))

  polygons <- sf::st_read(args$polygons, quiet = TRUE)
  wsim.io::infof('Read %d polygons from %s', nrow(polygons), args$polygons)

  append_cols <- stringr::str_split(args$append_cols, stringr::fixed(','))[[1]]

  breaks <- sapply(stringr::str_split(args$breaks, stringr::fixed(','))[[1]], as.numeric)
  labels <- c(
      paste('lt', breaks[1], sep = '_'),
      paste(breaks[-length(breaks)], breaks[-1], sep = '_'),
      paste('gt', breaks[length(breaks)], sep = '_'))

  # reclassify
  rcmat <- cbind(
    breaks, c(breaks[-1], NA), seq_along(breaks)
  )
  value_cat <- terra::classify(values, rcmat,
                               include.lowest = TRUE,
                               right = FALSE, # intervals open on right, closed on left [3, 5)
                               othersNA = TRUE)
  value_cat[is.na(value_cat)] <- 0


  wsim.io::infof('Calculating summary fractions')
  results <- exact_extract(value_cat,
                           polygons,
                           fun = c('frac', 'weighted_frac'),
                           weights = weights,
                           coverage_area = TRUE,
                           default_weight = 0,
                           append_cols = append_cols,
                           colname_fun = function(values, weights, fun_name, fun_value, ...) {
                             if (is.na(weights)) {
                               weights <- 'area'
                               fun_name <- 'weighted_frac'
                             }
                             label = labels[fun_value + 1]
                             stringr::str_glue('{weights}_{fun_name}_{values}_{label}')
                           })

  wsim.io::infof('Writing results to %s', args$output)
  write.csv(results, args$output, row.names = FALSE)
}

tryCatch(main(commandArgs(trailingOnly=TRUE)), error=wsim.io::die_with_message)
