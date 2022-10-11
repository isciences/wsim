#!/usr/bin/env Rscript

# Copyright (c) 2021 ISciences, LLC.
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

wsim.io::logging_init('create_era5_mask')

suppressMessages({
  library(wsim.io)
})


'
Create a mask of pixels having greater than a specific fraction covered by land

Usage: create_era5_mask --input=<file> --output=<file> --threshold <amount>

Options:
--input <file>          ERA5 hourly precipitation for 1 month, netCDF format
--output <file>         Output file, netCDF
--threshold <amount>    Minimum fraction of pixel covered by land
'->usage

main <- function(raw_args) {
  args <- parse_args(usage, raw_args, types=list(threshold = 'numeric'))

  land_frac <- read_vars_from_cdf(args$input, vars = 'lsm')
  mask <- ifelse(land_frac$data[[1]] > args$threshold, 1, NA_integer_)

  write_vars_to_cdf(vars = list(is_land = mask),
                    filename = args$output,
                    extent = land_frac$extent)
}

main(commandArgs(trailingOnly = TRUE))
