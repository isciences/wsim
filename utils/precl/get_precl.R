#!/usr/bin/env Rscript

# Copyright (c) 2020 ISciences, LLC.
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

'
Download PREC/L monthly precipitation rates

Usage: get_precl.R (--yearmon=<yearmon> --output=<file>)

Options:
--yearmon <yearmon>    Year and month of data to read
--output <file>        Path of output netCDF file
'->usage

suppressMessages({
  library(wsim.io)
})

logging_init('get_precl')

main <- function(raw_args) {
  args <- parse_args(usage, raw_args)

  year <- as.integer(substr(args$yearmon, 1, 4))
  month <- as.integer(substr(args$yearmon, 5, 6))
  outfile <- args$output

  if (!can_write(outfile)) {
    stop(sprintf('Cannot write to %s. Does the directory exist?', outfile))
  }

  download_precl(outfile, year, month)
}

tryCatch(main(commandArgs(trailingOnly=TRUE)),
         error=die_with_message)
