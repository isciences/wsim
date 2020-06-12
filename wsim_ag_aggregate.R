#!/usr/bin/env Rscript

# Copyright (c) 2019-2020 ISciences, LLC.
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

wsim.io::logging_init('wsim_ag_aggregate')
suppressMessages({
  library(Rcpp)
  library(dplyr)
  library(exactextractr)
  library(purrr)
  library(raster)
  library(sf)
  library(tidyr)
  library(wsim.agriculture)
  library(wsim.io)
})

'
Aggregate agricultural losses to polygonal boundaries

Usage: wsim_ag_aggregate --boundaries <file> --id_field <name> --prod_i <file> --prod_r <file> --yield_anom <file> --output <file>

Options:
--boundaries <file>   Boundaries over which to aggregate
--id_field <name>     Name of boundary ID field
--prod_i <file>       netCDF file with irrigated production for each crop
--prod_r <file>       netCDF file with rainfed production for each crop
--yield_anom <file>   netCDF file with yield anomalies
--output <file>       File to which aggregated results should be written
'->usage

#test_args <- list(
#  prod_i = '/home/dan/wsim/may12/source/SPAM2010/production_irrigated.nc',
#  prod_r =  '/home/dan/wsim/may12/source/SPAM2010/production_rainfed.nc',
#  #yield_anom = '/home/dan/wsim/may12/derived/agriculture/results/results_1mo_201912.nc',
#  yield_anom = '/home/dan/wsim/may12/derived/agriculture/results_summary/results_summary_1mo_202005.nc',
#  boundaries = '/home/dan/wsim/may12/source/HydroBASINS/basins_lev07.shp',
#  #boundaries = '/home/dan/data/gadm36_level_0.gpkg',
#  id_field = 'HYBAS_ID',
#  output = '/tmp/country_results_1mo_201912_stk.nc'
#)

main <- function(raw_args) {
  args <- parse_args(usage, raw_args)

  idcol <- args$id_field
  
  poly <- st_read(args$boundaries)
  id_values <- poly[[args$id_field]] 
  crops <- wsim_crops[wsim_crops$implemented, 'wsim_name']
  
  # Probe the anomaly files to see if losses are expressed as quantiles
  loss_quantiles <- wsim.io::parse_quantiles(wsim.io::read_varnames(args$yield_anom))
  if (length(loss_quantiles) > 0) {
    wsim.io::info('Inputs available at the following quantiles:', loss_quantiles)
  }
  
  as_raster <- function(vars, crs=NA) {
    rasters <- sapply(vars$data, function(vals) {
      raster::raster(vals,
                     xmn=vars$extent[1],
                     xmx=vars$extent[2],
                     ymn=vars$extent[3],
                     ymx=vars$extent[4],
                     crs=CRS(sprintf('+init=epsg:%d', crs)))
    }, USE.NAMES=TRUE)
    if (length(rasters) == 1) {
      return(rasters[[1]])
    } else {
      return(raster::stack(rasters))
    }
  }
  
  results <- map_dfr(crops, function(crop) {
    crop_prod_tot <- NULL 
    crop_prod_adj <- NULL
    
    for (subcrop in wsim_subcrop_names(crop)) {
      infof('Processing %s', subcrop)
                  
      subcrop_prod_irr <- read_vars_from_cdf(args$prod_i, vars='production', extra_dims=list(crop=subcrop))$data[[1]]
      subcrop_prod_rf <- read_vars_from_cdf(args$prod_r, vars='production', extra_dims=list(crop=subcrop))$data[[1]]
      
      subcrop_prod_tot <- psum(subcrop_prod_irr, subcrop_prod_rf)
      
      if (is.null(crop_prod_tot)) {
        crop_prod_tot <- subcrop_prod_tot
      } else {
        crop_prod_tot <- psum(crop_prod_tot, subcrop_prod_tot)
      }
      
      # this needs to possibly be a stack
      anom <- as_raster(read_vars_from_cdf(args$yield_anom, extra_dims=list(crop=subcrop)), crs=4326)
      
      subcrop_prod_adj <- data.matrix(exact_extract(anom, poly[1], 'weighted_sum', 
                                                    weights=raster(subcrop_prod_tot, xmn=-180, xmx=180, ymn=-90, ymx=90, crs=crs(anom))))
      
      if (is.null(crop_prod_adj)) {
        crop_prod_adj <- subcrop_prod_adj
      } else {
        crop_prod_adj <- psum(crop_prod_adj, subcrop_prod_adj)
        dimnames(crop_prod_adj) <- dimnames(subcrop_prod_adj)
      }
    }
    
    crop_prod <- exact_extract(raster(crop_prod_tot, xmn=-180, xmx=180, ymn=-90, ymx=90, crs=crs(anom)), poly, 'sum')
    
    cbind(
      data.frame(
        id = id_values,
        crop = crop
      ),
      crop_prod_adj / crop_prod
    )
  })
  
  results <- dplyr::rename_at(results, 
                              dplyr::vars(dplyr::starts_with('weighted_sum')),
                              function(n) sub('weighted_sum.', '', n, fixed=TRUE))
  
  
  write_vars_to_cdf(results,
                    args$output,
                    ids=id_values,
                    extra_dims=list(crop=crops),
                    prec='single')
  
  infof('Wrote per-crop aggregated results to %s', args$output)
}

if (!interactive()) {
  tryCatch(
    main(commandArgs(trailingOnly=TRUE))
    ,error=wsim.io::die_with_message)
}
