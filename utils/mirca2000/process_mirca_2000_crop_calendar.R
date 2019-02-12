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

wsim.io::logging_init('process_mirca_2000_crop_calendar')
suppressMessages({
  require(dplyr)
  library(Rcpp)
  require(wsim.io)
  require(wsim.agriculture)
})

'
Prepare crop calendar netCDF from MIRCA2000 condensed crop calendar format

Usage: process_mirca_2000_crop_calendar --condensed_calendar <file> --regions <file> --res <degrees> --output <file> 

Options:
--condensed_calendar <file>  Condensed crop calendar file
--regions <file>             Region raster
--res <degrees>              Output resolution (degrees)
--output <file>              Output netCDF file
'->usage

test_args <- list(
  '--condensed_calendar', '/home/dbaston/Downloads/condensed_cropping_calendars/cropping_calendar_rainfed.txt',
  '--regions',            '/home/dbaston/Downloads/unit_code_grid/unit_code.asc',
  '--res',                0.5,
  '--output',             '/tmp/calendar.nc'
)

main <- function(raw_args) {
  args <- wsim.io::parse_args(usage, raw_args)  
  
  calendar <- parse_mirca_condensed_crop_calendar(
    args$condensed_calendar) %>%
    group_by(unit_code, crop) %>%
    mutate(area_frac= area_ha/sum(area_ha)) %>%
    as.data.frame()
  
  regions <- read_vars(args$regions)$data[[1]]
  
  start_days <- c(1,  32, 60, 91,  121, 152, 182, 213, 244, 274, 305, 335)
  end_days   <- c(31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334, 365)
  
  # FIXME calculate dynamically
  aggregation_factor <- 0.5*60 / 5 # 5 arc-minute to half-degree
  
  plant_date <- list()
  harvest_date <- list()
  
  for (i in 1:nrow(mirca_crops)) {
    crop_id <- mirca_crops[i, 'mirca_id']
    crop_name <- mirca_crops[i, 'mirca_name']
    for (subcrop_id in 1:mirca_crops[i, 'mirca_subcrops']) {
      crop_string <- sprintf('%s_%d', gsub('[\\s/]+', '_', crop_name, perl=TRUE), subcrop_id)
      cat(crop_string, '\n')
      
      reclass_matrix <- as.matrix(calendar[calendar$crop==crop & calendar$subcrop==subcrop, c('unit_code', 'plant_month', 'harvest_month')],
                                  rownames.force=FALSE)
      reclass_matrix[, 2] <- start_days[reclass_matrix[, 2]]
      reclass_matrix[, 3] <- end_days[reclass_matrix[, 3]]
      plant_date[[crop_string]] <- aggregate_mean_doy(wsim.agriculture::reclassify(regions, reclass_matrix[, c(1,2)], TRUE), aggregation_factor)
      harvest_date[[crop_string]] <- aggregate_mean_doy(wsim.agriculture::reclassify(regions, reclass_matrix[, c(1,3)], TRUE), aggregation_factor)
    }
  }
  
  stk <- function(...) abind::abind(..., along=3)
  write_vars_to_cdf(
    list(
      plant_date=do.call(stk, plant_date),
      harvest_date=do.call(stk, harvest_date)),
    extent=c(-180, 180, -90, 90),
    '/tmp/calendar.nc',
    extra_dims=list(crop=names(plant_date)))
  
  for (cname in names(plant_date)) {
    cat(cname, '\n')
    d <- read_vars_from_cdf('/tmp/calendar.nc', extra_dims=c(crop=cname))
    
    expect_equal(d$data$plant_date, plant_date[[cname]], check.attributes=FALSE)
    expect_equal(d$data$harvest_date, harvest_date[[cname]], check.attributes=FALSE)
  }
}