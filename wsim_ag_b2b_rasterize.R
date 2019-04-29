#!/usr/bin/env Rscript

# Copyright (c) 2019 ISciences, LLC.
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
  library(sf)
  library(dplyr)
  library(fasterize)
  library(wsim.io)
})

wsim.io::logging_init('wsim_ag_b2b_rasterize')

'
Produce gridded variably-integrated blue water return periods from basin-to-basin accumulation

Usage: b2b_rasterize --basins=<file> --windows=<file> --bt_ro=<file>... --fit=<file>... --res=<value> --output=<file>

Options:
--basins <file>    Basin geometries
--windows <file>   Basin integration period (months)
--bt_ro <files>    Basin total blue water [m^3]
--fit <files>      Basin total blue water distribution fits
--output <file>    Output loss risk by basin
--res <value>      Resolution of output raster (degrees)
'->usage

test_args <- list(
  "--bt_ro",   "/home/dbaston/wsim/oct22/basin_results/basin_results_1mo_201801.nc::Bt_RO",
  "--bt_ro",   "/home/dbaston/wsim/oct22/basin_results_integrated/basin_results_3mo_201801.nc::Bt_RO_sum",
  "--bt_ro",   "/home/dbaston/wsim/oct22/basin_results_integrated/basin_results_6mo_201801.nc::Bt_RO_sum",
  "--bt_ro",   "/home/dbaston/wsim/oct22/basin_results_integrated/basin_results_12mo_201801.nc::Bt_RO_sum",
  "--bt_ro",   "/home/dbaston/wsim/oct22/basin_results_integrated/basin_results_24mo_201801.nc::Bt_RO_sum",
  "--bt_ro",   "/home/dbaston/wsim/oct22/basin_results_integrated/basin_results_36mo_201801.nc::Bt_RO_sum",
  "--fit",     "/home/dbaston/wsim/oct22/fits/basin_Bt_RO_1mo_month_01.nc",
  "--fit",     "/home/dbaston/wsim/oct22/fits/basin_Bt_RO_sum_3mo_month_01.nc",
  "--fit",     "/home/dbaston/wsim/oct22/fits/basin_Bt_RO_sum_6mo_month_01.nc",
  "--fit",     "/home/dbaston/wsim/oct22/fits/basin_Bt_RO_sum_12mo_month_01.nc",
  "--fit",     "/home/dbaston/wsim/oct22/fits/basin_Bt_RO_sum_24mo_month_01.nc",
  "--fit",     "/home/dbaston/wsim/oct22/fits/basin_Bt_RO_sum_36mo_month_01.nc",
  "--windows", "/home/dbaston/wsim/oct22/electricity/spinup/basin_upstream_storage.nc",
  "--basins",  "/mnt/fig_rw/WSIM_DEV/source/HydroBASINS/basins_lev05.shp",
  "--res",     "0.5",
  "--output",  "/tmp/rasterized.nc"
)

main <- function(raw_args) {
  args <- wsim.io::parse_args(usage, raw_args, types=list(res="numeric"))

  basins <- st_read(args$basins, quiet=TRUE)
  basin_ids <- basins$HYBAS_ID
  
  basin_windows <- wsim.io::read_vars(args$windows, expect.nvars=1, expect.ids=basin_ids, as.data.frame=TRUE)
  
  fits  <- wsim.io::read_integrated_vars(wsim.io::expand_inputs(args$fit), basin_ids)
  bt_ro <- wsim.io::read_integrated_vars(wsim.io::expand_inputs(args$bt_ro), basin_ids)
  names(bt_ro) <- c('id', 'flow', 'window')
  
  required_windows <- sort(unique(basin_windows$months_storage))
  for (w in required_windows) {
    if (!(w %in% bt_ro$window))
      stop("No blue water data found for integration window of ", w, " months.")

    if (!(w %in% fits$window))
      stop("No blue water fits found for integration window of ", w, " months.")
  }
  
  cdfxxx <- wsim.distributions::find_cdf(attr(fits, 'distribution'))
  
  cdf_vectorized <- Vectorize(function(val, loc, scale, shape) {
    if(is.na(loc) || is.na(scale) || is.na(shape))
      NA_real_
    else
      cdfxxx(val, c(loc, scale, shape))
  })
  
  # Initially rasterize at a higher resolution and then aggregate.
  fact <- 6
  res <- args$res
  
  # Figure out the return period for each basin up front, so that we can delay
  # working with sf objects as long as possible. (There is a large penalty for each
  # operation on sf objects.)
  return_periods <- basin_windows %>%
    inner_join(fits,  by=c('id', months_storage='window')) %>%
    inner_join(bt_ro, by=c('id', months_storage='window')) %>%
    transmute(id, 
              rp=pmax(-60,
                      pmin(60, 
                      wsim.distributions::quantile2rp(cdf_vectorized(flow, location, scale, shape)))))
    
  rasterized <- basins %>%
    select(id=HYBAS_ID) %>%
    inner_join(return_periods, by=c('id')) %>%
    fasterize(raster::raster(xmn=-180, xmx=180, ymn=-90, ymx=90, nrows=180/res*fact, ncols=360/res*fact),
              field='rp') %>%
    raster::as.matrix() %>%
    wsim.agriculture::aggregate_mean(fact)

  wsim.io::write_vars_to_cdf(
    list(Bt_RO_rp=rasterized),
    args$output,
    extent=c(-180, 180, -90, 90))
}

tryCatch(main(commandArgs(trailingOnly=TRUE)), error=wsim.io::die_with_message)