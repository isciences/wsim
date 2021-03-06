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
  require(abind)
  require(dplyr)
  require(wsim.io)
  require(wsim.agriculture)
})

'
Prepare crop calendar netCDF from MIRCA2000 condensed crop calendar format

Usage: process_mirca_2000_crop_calendar --condensed_calendar <file>... --regions <file> --res <degrees> --output <file> 

Options:
--condensed_calendar <file>  Condensed crop calendar file(s)
--regions <file>             Region raster
--res <degrees>              Output resolution (degrees)
--output <file>              Output netCDF file
'->usage

#test_args <- list(
#  '--condensed_calendar', '/home/dbaston/Downloads/condensed_cropping_calendars/cropping_calendar_rainfed.txt',
#  '--regions',            '/home/dbaston/Downloads/unit_code_grid/unit_code.asc',
#  '--res',                0.5,
#  '--output',             '/tmp/calendar.nc'
#)

main <- function(raw_args) {
  args <- wsim.io::parse_args(usage, raw_args, types=list(res="numeric"))  
  
  calendars <- lapply(args$condensed_calendar, read_mirca_crop_calendar)
  calendar <- do.call(combine_calendars, calendars) 
  
  infof("Read %d crop calendars.", length(calendars))
  
  regions <- read_vars(args$regions, expect.nvars=1)
  extent <- regions$extent 
  regions <- regions$data[[1]]
  
  res <- c((extent[4]-extent[3])/dim(regions)[1], (extent[2]-extent[1])/dim(regions)[2])
  stopifnot(res[1]==res[2])
  aggregation_factor <- args$res/res[1]
  infof('Aggregating from %f-degree pixels to %f-degree pixels', res[1], res[1]*aggregation_factor)
  stopifnot(aggregation_factor >= 1)
  stopifnot(aggregation_factor == round(aggregation_factor))
  
  plant_date <- list()
  harvest_date <- list()
  area_frac <- list()
  
  for (i in 1:nrow(mirca_crops)) {
    mirca_crop_id <- mirca_crops[i, 'mirca_id']
    wsim_crop_id <- mirca_crops[i, 'wsim_id']
    
    if (!is.na(wsim_crop_id)) {
      crop_name <- wsim_crops[wsim_crops$wsim_id==wsim_crop_id, 'wsim_name']
    
      num_subcrops <- mirca_crops[i, 'mirca_subcrops']
      for (subcrop_id in 1:num_subcrops) {
        crop_string <- ifelse(num_subcrops > 1,
                              sprintf('%s_%d', crop_name, subcrop_id),
                              crop_name)
        infof('Constructing calendar for %s (%d/%d)', crop_name, subcrop_id, num_subcrops)
        
        plant_date[[crop_string]] <- aggregate_mean_doy(
          mirca_plant_date_grid(regions, calendar, mirca_crop_id, subcrop_id),
          aggregation_factor
        )
        
        harvest_date[[crop_string]] <- aggregate_mean_doy(
          mirca_harvest_date_grid(regions, calendar, mirca_crop_id, subcrop_id),
          aggregation_factor)
        
        area_frac[[crop_string]] <- aggregate_mean(
          mirca_area_fraction_grid(regions, calendar, mirca_crop_id, subcrop_id),
          aggregation_factor)
      }
    }
  }
  
  write_vars_to_cdf(
    list(
      plant_date=abind(plant_date, along=3),
      harvest_date=abind(harvest_date, along=3),
      area_frac=abind(area_frac, along=3)),
    extent=extent,
    args$output,
    extra_dims=list(crop=names(plant_date)),
    prec=list(area_frac='single',
              plant_date='short',
              harvest_date='short')
  )
  
  infof('Wrote crop calendar to %s', args$output)
}

#tryCatch(
  main(commandArgs(trailingOnly=TRUE))
#, error=wsim.io::die_with_message)