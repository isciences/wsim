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
})

wsim.io::logging_init('wsim_electricity_plant_losses')

'
Estimate plant-level electrical generation loss risk

Usage: wsim_electricity_plant_losses --basin_losses=<file> --basin_temp=<file> --plants=<file> --temperature=<file> --temperature_rp=<file> --output=<file>

Options:
--basin_losses <file>   Water-cooled losses for each basin
--basin_temp <file>     Basin air temperature
--plants <file>         Power plants
--temperature <file>    Temperature values
--temperature_rp <file> Temperature return periods
--output <file>         Output loss risk by basin
'->usage

var_to_raster <- function(vars) {
  stopifnot(length(vars$data) == 1)
  raster::raster(vars$data[[1]],
                 xmn=vars$extent[1],
                 xmx=vars$extent[2],
                 ymn=vars$extent[3],
                 ymx=vars$extent[4])
}

main <- function(raw_args) {
  #raw_args <- list(
  #  '--plants',         '/home/dbaston/wsim/oct22/electricity/spinup/power_plants.nc',
  #  '--basin_losses',   '/home/dbaston/wsim/oct22/electricity/basin_loss_risk/basin_loss_risk_201801.nc',
  #  '--basin_temp',     '/home/dbaston/wsim/oct22/basin_results/basin_results_1mo_201801.nc::T_Bt_RO',
  #  '--temperature',    '/home/dbaston/wsim/oct22/forcing/forcing_201801.nc::T',
  #  '--temperature_rp', '/home/dbaston/wsim/oct22/rp/rp_1mo_201801.nc::T_rp',
  #  '--output',         '/tmp/cookie.nc'
  #)

  args <- wsim.io::parse_args(usage, raw_args)

  plants <- wsim.io::read_vars(args$plants, as.data.frame=TRUE)

  basin_losses <- wsim.io::read_vars(args$basin_losses,
                                     expect.nvars=2,
                                     as.data.frame=TRUE)
  basin_temp <- wsim.io::read_vars(args$basin_temp,
                                   expect.nvars=1,
                                   as.data.frame=TRUE)

  temp <- var_to_raster(wsim.io::read_vars(args$temperature))
  temp_rp <- var_to_raster(wsim.io::read_vars(args$temperature_rp))

  # assign air temperature and temperature return period to each plant
  # TODO get rid of dplyr attribute warnings
  plant_losses <- plants %>%
    left_join(select(basin_losses,
                     id,
                     basin_hydro_loss=hydropower_loss,
                     basin_water_cooled_loss=water_cooled_loss),
              by=c(basin_id="id")) %>%
    left_join(select(basin_temp,
                     id, basin_temp=2),
              by=c(basin_id="id")) %>%
    mutate(
      plant_temp= raster::extract(temp, cbind(longitude, latitude)),
      plant_temp_rp= raster::extract(temp_rp, cbind(longitude, latitude)),
      loss_hydro= (fuel=='Hydro')*basin_hydro_loss,
      loss_water_cooled= water_cooled*basin_water_cooled_loss,
      loss_temperature= wsim.electricity::temperature_loss(To= plant_temp,
                                           To_rp= plant_temp_rp,
                                           Tbas= coalesce(basin_temp, plant_temp_rp), # fallback to plant temp
                                           Tc= -15, # TODO check against report
                                           Tc_rp= -30, # TODO check against report
                                           Treg= ifelse(once_through, 32, NA),
                                           Tdiff= 8),
      loss_risk= pmin(1, coalesce(loss_hydro, 0) +
                         coalesce(loss_water_cooled, 0) +
                         loss_temperature) # TODO make sure these should be additive
    )

  # TODO get rid of unwanted columns

  wsim.io::info("Writing plant losses to", args$output)
  wsim.io::write_vars_to_cdf(plant_losses[, -1],
                             args$output,
                             ids=plant_losses[, 1])
}

tryCatch(main(commandArgs(trailingOnly=TRUE)), error=wsim.io::die_with_message)
