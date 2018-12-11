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

suppressMessages({
  require(dplyr)
  require(Rcpp)
})

wsim.io::logging_init('wsim_electricity_basin_losses')

'
Estimate basin-level electrical generation loss risk

Usage: wsim_electricity_basin_losses --windows=<file> --stress=<file> --bt_ro=<file>... --bt_ro_fit=<file>... --bt_ro_min_fit=<file>... --output=<file>

Options:
--windows <file>        Basin integration period (months)
--stress <file>         Basin baseline water stress
--bt_ro <files>         Basin total blue water [m^3]
--bt_ro_fit <files>     Basin total blue water distribution fits
--bt_ro_min_fit <files> Basin annual minimum total blue water distribution fits
--output <file>         Output loss risk by basin
'->usage

# Read fits from several files and return a list
# whose keys are integration periods in months
# and whose values are data frames for fit parameters
read_fits <- function(vardefs, expected_ids) {
  fits <- list()
  for (vardef in vardefs) {
    df <- wsim.io::read_vars(vardef, expect.ids=expected_ids, as.data.frame=TRUE)
    window <- attr(df, 'integration_window_months')
    df$window <- as.integer(window)
    fits[[as.character(window)]] <- df
  }

  do.call(function(...) rbind(..., make.row.names=FALSE), fits)
}

# Read total blue water from several files and
# return a list whose keys are integration periods
# in months and whose values are data frames for
# fit parameters
read_obs <- function(vardefs, expected_ids) {
  obs <- list()

  for (vardef in vardefs) {
    df <- wsim.io::read_vars(vardef, expect.ids=expected_ids, as.data.frame=TRUE)
    names(df) <- c('id', 'flow')
    window <- attr(df[, -1], 'integration_window_months')
    if (is.null(window))
      window <- 1
    df$window <- as.integer(window)
    obs[[as.character(window)]] <- df
  }

  do.call(function(...) rbind(..., make.row.names=FALSE), obs)
}

main <- function(raw_args) {
  args <- wsim.io::parse_args(usage, raw_args)

  basin_windows <- wsim.io::read_vars(args$window, expect.nvars=1, as.data.frame=TRUE)
  basin_ids <- basin_windows$id
  basin_bws <- wsim.io::read_vars(args$stress, expect.nvars=1, expect.ids=basin_ids, as.data.frame=TRUE)

  bt_ro_fits            <- read_fits(wsim.io::expand_inputs(args$bt_ro_fit), basin_ids)
  bt_ro_annual_min_fits <- read_fits(wsim.io::expand_inputs(args$bt_ro_min_fit), basin_ids)
  bt_ro                 <- read_obs(wsim.io::expand_inputs(args$bt_ro), basin_ids)

  required_windows <- sort(unique(basin_windows$months_storage))
  for (w in required_windows) {
    if (!(w %in% bt_ro$window))
      stop("No blue water data found for integration window of ", w, " months.")

    if (!(w %in% bt_ro_fits$window))
      stop("No blue water fits found for integration window of ", w, " months.")
    
    if (!(w %in% bt_ro_annual_min_fits$window))
      stop("No blue water annual minimum fits found for integration window of ", w, " months.")
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
    inner_join(basin_bws, by='id') %>%
    left_join(bt_ro, by=c('id', 'window')) %>%
    left_join(select(bt_ro_fits, id, window, month_location=location, month_scale=scale, month_shape=shape), by=c('id', 'window')) %>%
    left_join(select(bt_ro_annual_min_fits, id, window, annual_min_location=location, annual_min_scale=scale, annual_min_shape=shape), by=c('id', 'window')) %>%
    mutate(annual_min_flow_quantile=cdf_vectorized(flow, annual_min_location, annual_min_scale, annual_min_shape),
           annual_min_flow_rp=wsim.distributions::quantile2rp(annual_min_flow_quantile),
           month_flow_median=med_vectorized(month_location, month_scale, month_shape))

  basins$water_cooled_loss <- wsim.electricity::water_cooled_loss(
    -basins$annual_min_flow_rp,
    wsim.electricity::water_cooled_loss_onset(basins$baseline_water_stress),
    wsim.electricity::water_cooled_loss_onset(basins$baseline_water_stress) + 30)

  basins$hydropower_loss <- wsim.electricity::hydropower_loss(basins$flow, basins$month_flow_median, 0.6)

  wsim.io::write_vars_to_cdf(vars=basins[, c('annual_min_flow_quantile', 'annual_min_flow_rp', 'month_flow_median', 'water_cooled_loss', 'hydropower_loss')],
                             filename=args$output,
                             ids=basins$id)
}

tryCatch(main(commandArgs(TRUE)), error=wsim.io::die_with_message)
