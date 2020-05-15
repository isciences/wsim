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

suppressMessages({
  require(dplyr)
  require(Rcpp)
})

wsim.io::logging_init('wsim_electricity_basin_losses')

'
Estimate basin-level electrical generation loss risk

Usage: wsim_electricity_basin_losses.R --windows=<file> --bt_ro=<file>... --bt_ro_fit=<file>... --output=<file>

Options:
--windows <file>        Basin integration period (months)
--bt_ro <files>         Basin total blue water [m^3]
--bt_ro_fit <files>     Basin total blue water distribution fits
--output <file>         Output loss risk by basin
'->usage


main <- function(raw_args) {
  args <- wsim.io::parse_args(usage, raw_args)

  basin_windows <- wsim.io::read_vars(args$window, expect.nvars=1, as.data.frame=TRUE) %>%
    mutate(months_storage = pmax(months_storage, 12L))  # assume minimum 12 months storage
  basin_ids <- basin_windows$id

  bt_ro_fits            <- wsim.io::read_integrated_vars(wsim.io::expand_inputs(args$bt_ro_fit), basin_ids)
  bt_ro                 <- wsim.io::read_integrated_vars(wsim.io::expand_inputs(args$bt_ro), basin_ids)
  names(bt_ro) <- c('id', 'flow', 'window')

  required_windows <- sort(unique(basin_windows$months_storage))
  for (w in required_windows) {
    if (!(w %in% bt_ro$window))
      stop("No blue water data found for integration window of ", w, " months.")

    if (!(w %in% bt_ro_fits$window))
      stop("No blue water fits found for integration window of ", w, " months.")
  }

  quaxxx <- wsim.distributions::find_qua(attr(bt_ro_fits, 'distribution'))
  cdfxxx <- wsim.distributions::find_cdf(attr(bt_ro_fits, 'distribution'))

  cdf_vectorized <- Vectorize(function(val, loc, scale, shape) {
    if(is.na(loc) || is.na(scale) || is.na(shape))
      NA_real_
    else
      cdfxxx(val, c(loc, scale, shape))
  })

  med_vectorized <- Vectorize(function(loc, scale, shp) {
    if(is.na(loc) || is.na(scale) || is.na(shp))
      loc
    else
      quaxxx(0.5, c(loc, scale, shp))
  })

  # TODO get rid of dplyr noise about attribute mismatch
  basins <- select(basin_windows, id, window=months_storage) %>%
    left_join(bt_ro, by=c('id', 'window')) %>%
    left_join(select(bt_ro_fits, id, window, month_location=location, month_scale=scale, month_shape=shape), by=c('id', 'window')) %>%
    mutate(month_flow_median=med_vectorized(month_location, month_scale, month_shape))
  
  basins$hydropower_loss <- wsim.electricity::hydropower_loss(basins$flow, basins$month_flow_median)
  
  wsim.io::write_vars_to_cdf(vars=basins[, c('hydropower_loss'), drop=FALSE],
                             filename=args$output,
                             ids=basins$id)
  
  wsim.io::infof('Wrote basin loss factors to %s', args$output)
}

tryCatch(main(commandArgs(TRUE)), error=wsim.io::die_with_message)
