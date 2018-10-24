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

wsim.io::logging_init('table2nc')

'
Extract field(s) from an GDAL vector source to a netCDF

Usage: table2nc.R --input=<files>... --column=<col_name>... --fid=<column> --output=<file>

--input=<files>     one or more input files
--column=<col_name> one or more columns to read
--fid=<column>      name of id column
--output=<file>     name of output netCDF file
'->usage

suppressMessages({
  require(sf)
  require(readr)
  require(wsim.io)
})

main <- function(raw_args) {
  args <- parse_args(usage, raw_args)

  features <- NULL

  for (input_arg in args$input) {
    for (input in expand_inputs(input_arg)) {
      info('Reading attributes from', input)
      if (endsWith(input, 'csv')) {
        suppressMessages(feat <- read_csv(input)[c(args$fid, args$column)])
      } else {
        capture.output(feat <- st_read(input)[c(args$fid, args$column)])
        st_geometry(feat) <- NULL
      }
      if (is.null(features)) {
        features <- feat
      } else {
        features <- rbind(features, feat)
      }
    }
  }
  
  names(features) <- tolower(names(features))

  write_vars_to_cdf(vars=features[tolower(args$column)],
                    ids= unname(unlist(features[, tolower(args$fid)])),
                    #prec='integer',
                    filename= args$output
  )

  info('Wrote attributes to', args$output)
}

#tryCatch(
  main(commandArgs(trailingOnly=TRUE))
  #, error=wsim.io::die_with_message)
