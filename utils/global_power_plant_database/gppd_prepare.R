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

wsim.io::logging_init('gppd_prepare')

'
Prepare GPPD data for use with WSIM electric power assessment

Usage: gppd_prepare --plants=<file> --basins=<file> --coast=<file> --countries=<file> --provinces=<file> --output=<file> [--seawater_distance <dist>]

Options:
--plants <file>            Point dataset of GPPD data
--basins <file>            Polygon dataset of hydrologic basins
--coast <file>             Linear dataset of coastlines
--countries <file>         Polygon dataset of country boundaries
--provinces <file>         Polygon dataset of province boundaries
--output <file>            Output netCDF with prepared plant data
--seawater_distance <dist> Distance to coastline (in meters) to assume seawater cooling [default: 3000]
'->usage

# Define a function to create a geodesic buffer around some point,, with a
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
  plants <- st_read(args$plants, stringsAsFactors=FALSE)

  # TODO check that args$output is writable
  # TODO suppress sf noise throughout file (st_read and st_intersects)
  # TODO pull these out into arguments
  plant_id_field <- 'gppd_idnr'
  basin_id_field <- 'HYBAS_ID'
  country_field <- 'NAME_0'
  province_field <- 'NAME_1'

  wsim.io::info("Creating", args$seawater_distance, "buffer around power plant locations.")
  plants_buff <- plants %>%
    select(!!plant_id_field) %>%
    st_set_geometry(geod_buffer(., args$seawater_distance))

  # Subdivide the coast into shorter segments to make joining
  # faster.
  coast  <- st_read(args$coast,  stringsAsFactors=FALSE)
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
    group_by(!!plant_id_field) %>%
    summarize(near_coast=any(!is.na(coast_part)))
  rm(coast_subd)

  # Join plants to hydrologic basins
  # Use basins for the first argument for performance reasons;
  # see https://github.com/r-spatial/sf/issues/885
  wsim.io::info("Assigning plants to hydrologic basins")
  basins <- st_read(args$basins, stringsAsFactors=FALSE)
  plant_basins <- select(basins, basin_id=!!basin_id_field) %>%
    st_join(plants, join=st_intersects, left=FALSE) %>%
    st_set_geometry(NULL) %>%
    group_by(!!plant_id_field) %>%
    summarise(basin_id = min(basin_id))
  rm(basins)

  # Join plants to countries
  wsim.io::info("Assigning plants to countries")
  countries <- st_read(args$countries, stringsAsFactors=FALSE)
  plants_countries <- select(countries, name=!!country_field) %>%
    st_join(select(plants, !!plant_id_field), join=st_intersects, left=FALSE) %>%
    st_set_geometry(NULL) %>%
    group_by(!!plant_id_field) %>%
    summarise(country = min(name))
  rm(countries)

  # Join plants to provinces
  wsim.io::info("Assigning plants to provinces")
  provinces <- st_read(args$provinces, stringsAsFactors=FALSE)
  plants_provinces <- select(provinces, name=!!province_field) %>%
    st_join(select(plants, !!plant_id_field), join=st_intersects, left=FALSE) %>%
    st_set_geometry(NULL) %>%
    group_by(!!plant_id_field) %>%
    summarise(province = min(name))
  rm(provinces)

  # set default cooling types
  plants_out <- plants %>%
    select(!!plant_id_field, capacity_mw, fuel1) %>%
    left_join(plant_basins, by=plant_id_field) %>%
    inner_join(plants_near_coast, by=plant_id_field) %>%
    left_join(plants_countries, by=plant_id_field) %>%
    left_join(plants_provinces, by=plant_id_field) %>%
    transmute(
      !!plant_id_field,
      basin_id,
      country,
      province,
      capacity_mw,
      fuel=fuel1,
      water_cooled= fuel1 %in% c('Coal', 'Nuclear', 'Waste', 'Biomass', 'Cogeneration', 'Petcoke'),
      once_through= water_cooled & runif(nrow(.)) < 0.2, # TODO FIXME
      seawater_cooled= water_cooled & near_coast
    ) %>%
    cbind(st_coordinates(.)) %>%
    rename(longitude=X, latitude=Y) %>%
    st_set_geometry(NULL)

  wsim.io::info("Writing plants to", args$output)
  wsim.io::write_vars_to_cdf(plants_out[, -1],
                             output,
                             ids=plants_out[, 1],
                             prec=list(basin_id='integer',
                                       capacity_mw='single',
                                       longitude='single',
                                       latitude='single'))
}

test_args <- list(
  '--plants',    '/home/dbaston/data/global_power_plant_database.gpkg',
  '--basins',    '/mnt/fig_rw/WSIM_DEV/source/HydroBASINS/basins_lev05.shp',
  '--coast',     '/home/dbaston/Downloads/ne_10m_coastline/ne_10m_coastline.shp',
  '--countries', '/home/dbaston/Downloads/gadm36.gpkg',
  '--provinces', '/home/dbaston/Downloads/gadm36.gpkg',
  '--output',    '/tmp/plants.nc'
)

tryCatch(main(commandArgs(trailingOnly=TRUE)), error=wsim.io::die_with_message)
