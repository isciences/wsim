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
  require(Rcpp)
})

wsim.io::logging_init('wsim_electricity_basin_losses')

'
Estimate basin-level electrical generation loss risk

Usage: wsim_electricity_basin_losses --windows=<file> --stress=<file> --bt_ro=<file>... --bt_ro_fit=<file>... --output=<file>

Options:
--windows <file>    Basin integration period (months)
--stress <file>     Basin baseline water stress
--bt_ro <files>     Basin total blue water [m^3]
--bt_ro_fit <files> Basin total blue water distribution fits
--output <file>     Output loss risk by basin
'->usage

# example
# --bt_ro "/home/dbaston/wsim/jul31/basin_results/basin_results_1mo_201801.nc" --bt_ro "/home/dbaston/wsim/jul31/basin_results_integrated/basin_results_*mo_201801.nc"
# --bt_ro_fit "/home/dbaston/wsim/jul31/fits/basin_Bt_RO_*mo_month_04.nc"


# TODO need a "window" variable on results and fits

#' Validate that total blue water values and distributions
#' have been provided for all required integration windows.
#' 
#' @param required_windows vector of required integration
#'                         windows [months]
#' @param bt_ro            a list of Bt_RO datasets having 
#'                         defined 'integration_window_months' attribute
#' @param bt_ro_fit        a list of fit datasets having a
#'                         defined 'window' attribute
validate_inputs <- function(required_windows, bt_ro, fits) {
  for (w in required_windows) {
    if (w != 1) {
      # integration window not included in 1-mo files
      if(!any(sapply(bt_ro, function(data) {
        w2 <- attr(data$data[[1]], 'integration_window_months')
        !is.null(w2) && w == w2 }))) {
        warning(sprintf('Could not find total blue water for integration window of %d months', w))
      }
    }
    
    if(!any(sapply(fits, function(data) {
      w2 <- data$attrs$integration_window_months
      !is.null(w2) && w == w2 }))) {
      warning(sprintf('Could not find total blue water fit for integration window of %d months', w))
    }
  }    
}

main <- function(raw_args) {
  args <- wsim.io::parse_args(usage, raw_args)
  
  basin_windows <- wsim.io::read_vars(args$window, expect.nvars=1)
  basin_ids <- basin_windows$ids
  basin_bws <- wsim.io::read_vars(args$stress, expect.nvars=1, expect.ids=basin_ids)$data[[1]] 
   
  bt_ro_fits <- lapply(wsim.io::expand_inputs(args$bt_ro_fit), function(vardef)
    wsim.io::read_vars(vardef, expect.ids=basin_ids))
  bt_ro <- lapply(wsim.io::expand_inputs(args$bt_ro), function(vardef)
    wsim.io::read_vars(vardef, expect.nvars=1, expect.ids=basin_ids))
  
  required_windows <- sort(unique(as.vector(basin_windows$data[[1]])))
  validate_inputs(required_windows, bt_ro, bt_ro_fits)
  
  for (w in required_windows) {
    # TODO implement.
    # Compute correct return period for each basin, given the 
    # integration period that should be used. Yes, this data
    # already exists somewhere, but it seems cleaner to calculate
    # it here than to require yet another input argument.
    bt_ro_rp <- NULL
    
    # Compute this using distribution for given integration window
    bt_ro_median <- NULL
  }
  
  # TODO merge everything into a data frame with
  # id | window | bt_ro | bt_ro_rp | bt_ro_location | bt_ro_scale | bt_ro_shape | bt_ro_median | bws
    
  basins$water_cooled_loss <- wsim.electricity::water_cooled_loss(basins$bt_ro_rp, basins$bws)
  basins$hydropower_loss   <- wsim.electricity::hydropower_loss(basins$bt_ro, basins$bt_ro_median, 0.6)
  
  # write output netCDF
  # id | water_cooled_loss | hydropower_loss |
}

test_args <- 
  list(
    "--windows","/home/dbaston/wsim/oct22/electricity/spinup/basin_upstream_storage.nc" ,
    "--stress","/home/dbaston/wsim/oct22/electricity/spinup/basin_baseline_water_stress.nc" ,
    "--output","/home/dbaston/wsim/oct22/electricity/basin_loss_risk/basin_loss_risk_201801.nc" ,
    "--bt_ro","/home/dbaston/wsim/oct22/basin_results/basin_results_1mo_201801.nc::Bt_RO" ,
    "--bt_ro","/home/dbaston/wsim/oct22/basin_results_integrated/basin_results_3mo_201801.nc::Bt_RO_sum" ,
    "--bt_ro","/home/dbaston/wsim/oct22/basin_results_integrated/basin_results_6mo_201801.nc::Bt_RO_sum" ,
    "--bt_ro","/home/dbaston/wsim/oct22/basin_results_integrated/basin_results_12mo_201801.nc::Bt_RO_sum" ,
    "--bt_ro","/home/dbaston/wsim/oct22/basin_results_integrated/basin_results_24mo_201801.nc::Bt_RO_sum" ,
    "--bt_ro","/home/dbaston/wsim/oct22/basin_results_integrated/basin_results_36mo_201801.nc::Bt_RO_sum" ,
    "--bt_ro_fit","/home/dbaston/wsim/oct22/fits/basin_Bt_RO_1mo_annual_min.nc" ,
    "--bt_ro_fit","/home/dbaston/wsim/oct22/fits/basin_Bt_RO_sum_3mo_annual_min.nc" ,
    "--bt_ro_fit","/home/dbaston/wsim/oct22/fits/basin_Bt_RO_sum_6mo_annual_min.nc" ,
    "--bt_ro_fit","/home/dbaston/wsim/oct22/fits/basin_Bt_RO_sum_12mo_month_12.nc" ,
    "--bt_ro_fit","/home/dbaston/wsim/oct22/fits/basin_Bt_RO_sum_24mo_month_12.nc" ,
    "--bt_ro_fit","/home/dbaston/wsim/oct22/fits/basin_Bt_RO_sum_36mo_month_12.nc" 
  )




