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
  library(wsim.io)
  library(dplyr)
  library(sf)
  library(lwgeom)
  library(geosphere)
})

wsim.io::logging_init('gppd_set_cooling')

'
Set cooling type fields for GPPD data

Usage: gppd_set_cooling --plants=<file> --once_through=<file> --coastline=<file> --output=<file> [--seawater_distance <dist>]

Options:
--plants <file>            Point dataset of GPPD data
--once_through <file>      Text file providing GPPD IDs for plants with once-through cooling
--coastline <file>         Linear dataset of coastlines
--seawater_distance <dist> Distance to coastline (in meters) to assume seawater cooling [default: 3000]
--output <file>            Output netCDF with prepared plant data
'->usage

# Define a function to create a geodesic buffer around some point, with a
# radius specified in meters. Return a simple feature collection.
geod_buffer <- function(pts, rad, segs_per_quad=32) {
  st_sfc(apply(st_coordinates(pts), 1, function(pt) {
     geosphere::destPoint(pt, seq(0, 360, length.out=4*segs_per_quad), rad) %>%
      list() %>%
      sf::st_polygon() %>%
      sf::st_wrap_dateline()
  }), crs=st_crs(pts))
}

main <- function(raw_args) {
  args <- wsim.io::parse_args(usage, raw_args, types=list(seawater_distance="numeric"))
  plants <- read.csv(args$plants, stringsAsFactors=FALSE) %>%
    st_as_sf(coords=c('longitude', 'latitude'), crs=4326, remove=FALSE)
  once_through_ids <- read.table(args$once_through, stringsAsFactors=FALSE)[, 1]

  wsim.io::info("Computing default capacity factors for each fuel type.")
  plant_capacity_factors <- plants %>%
    st_set_geometry(NULL) %>%
    mutate(generation_gwh= coalesce(generation_gwh_2017,
                                    generation_gwh_2016,
                                    generation_gwh_2015,
                                    generation_gwh_2014,
                                    generation_gwh_2013,
                                    estimated_generation_gwh),
           generation_mw= generation_gwh*1000/24/365.25,
           capacity_factor= pmin(1.0, generation_mw / capacity_mw)) %>%
    select(gppd_idnr, fuel=primary_fuel, capacity_factor)

  fuel_capacity_factors <- plant_capacity_factors %>%
    filter(capacity_factor > 0) %>%
    group_by(fuel) %>%
    summarize(mean_capacity_factor= mean(capacity_factor))

  plant_capacity_factors_adjusted <- plant_capacity_factors %>%
    inner_join(fuel_capacity_factors, by='fuel') %>%
    mutate(capacity_factor_adj= ifelse(is.na(capacity_factor) | capacity_factor <= 0,
                                       mean_capacity_factor,
                                       capacity_factor)) %>%
    select(gppd_idnr, capacity_factor=capacity_factor_adj)
  rm(plant_capacity_factors)
  rm(fuel_capacity_factors)

  wsim.io::info(sprintf("Creating %dm buffer around power plant locations.", args$seawater_distance))
  plants_buff <- plants %>%
    select(gppd_idnr) %>%
    st_set_geometry(geod_buffer(., args$seawater_distance))

  # Subdivide the coastline into shorter segments to make joining faster.
  coast  <- st_read(args$coastline,  stringsAsFactors=FALSE)
  wsim.io::info("Subdividing coastline boundary")
  coast_subd <- coast %>%
    st_subdivide(128) %>%
    st_collection_extract('LINESTRING') %>%
    transmute(coast_part=row_number())
  rm(coast)

  # Join plant buffers to subdivided coastline
  wsim.io::info("Identifying plants within", args$seawater_distance, "of coastline")
  plants_near_coast <- plants_buff %>%
    st_join(coast_subd, left=TRUE) %>%
    st_set_geometry(NULL) %>%
    group_by(gppd_idnr) %>%
    summarize(near_coast=any(!is.na(coast_part)))
  rm(coast_subd)

  # set default cooling types
  plants_out <- plants %>%
    filter(primary_fuel != 'Storage') %>%
    select(gppd_idnr, capacity_mw, primary_fuel, latitude, longitude) %>%
    inner_join(plants_near_coast, by='gppd_idnr') %>%
    inner_join(plant_capacity_factors_adjusted, by='gppd_idnr') %>%
    transmute(
      gppd_idnr,
      capacity_mw,
      generation_mw= capacity_factor*capacity_mw,
      fuel=primary_fuel,
      longitude,
      latitude,
      water_cooled= primary_fuel %in% c('Coal', 'Nuclear', 'Waste', 'Biomass', 'Cogeneration', 'Petcoke'),
      once_through= gppd_idnr %in% once_through_ids,
      seawater_cooled= water_cooled & near_coast
    ) %>%
    st_set_geometry(NULL)

  wsim.io::info("Writing plants to", args$output)
  wsim.io::write_vars_to_cdf(plants_out[, -1],
                             args$output,
                             ids=plants_out[, 1],
                             prec=list(basin_id='integer',
                                       capacity_mw='single',
                                       capacity_factor='single',
                                       longitude='single',
                                       latitude='single'))
}

tryCatch(main(commandArgs(trailingOnly=TRUE)), error=wsim.io::die_with_message)
