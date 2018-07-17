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

wsim.io::logging_init('wsim_extract')

suppressMessages({
  require(Rcpp)
  require(wsim.io)
  require(exactextractr)
  require(raster)
  require(sf)
})

'
Summarize gridded datasets based on polygon geometries

Usage: wsim_extract.R (--boundaries=<file>)... --fid <column> (--input=<input>)... (--stat=<stat>)... (--output=<output>)

Options:
--boundaries <file>   one or more datasets of polygonal boundaries
--fid <column>        name of polygon feature identifier
--input <input>       one or more sets of tabular data
--stat <stat>         one or more summary statistic (min, max, ave, sum)
--output <file>       output csv file
'->usage

main <- function(raw_args) {
  args <- parse_args(usage, raw_args, list(window="integer"))

  parsed_stats <- lapply(args$stat, parse_stat)

  # Create Raster objects and make a stack
  rasters <- list()
  for (vardef in args$input) {
    parsed_vardef <- parse_vardef(vardef)
    data <- wsim.io::read_vars(parsed_vardef)
    for (layer in names(data$data)) {
      rasters[[layer]] <- raster(data$data[[1]],
                                 xmn=data$extent[1],
                                 xmx=data$extent[2],
                                 ymn=data$extent[3],
                                 ymx=data$extent[4])
      info("Loaded", layer, "from", parsed_vardef$filename)
    }
  }

  first_file <- TRUE
  for (boundary_arg in args$boundaries) {
    for (boundary_file in expand_inputs(boundary_arg)) {
      info('Processing features in', boundary_file)

      for (line in (capture.output(features <- st_read(boundary_file)))) {
        info(line)
      }
      features <- features[args$fid]

      if (!(args$fid %in% names(features))) {
        die_with_message("ID field", args$fid, "not found.",
                         "(Fields:", names(features), ")")
      }

      for (var_name in names(rasters)) {
        stats_for_var <- Filter(function(stat) (length(stat$vars) == 0 || var_name %in% stat$vars), parsed_stats)
        stat_names <- sapply(stats_for_var, function(stat) stat$stat)
        field_names <- sapply(stat_names, function(stat) paste0(var_name, "_", stat))

        features[, field_names] <- exact_extract(rasters[[var_name]], features, fun=stat_names)
      }

      st_geometry(features) <- NULL

      if (endsWith(args$output, 'csv')) {
        write.table(features,
                    file=args$output,
                    sep=", ",
                    row.names=FALSE,
                    col.names=first_file,
                    append=!first_file)
      } else {
        write_vars_to_cdf(vars=features[field_names],
                          filename=args$output,
                          ids=features[, args$fid],
                          prec="single",
                          append=!first_file)
      }
      first_file <- FALSE
      info('Wrote', paste(field_names, collapse=", "), 'to', args$output)
    }
  }
}

main(commandArgs(trailingOnly=TRUE))
