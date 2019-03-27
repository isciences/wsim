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

wsim.io::logging_init('wsim_ag_aggregate')
suppressMessages({
  library(Rcpp)
  library(wsim.io)
  library(wsim.agriculture)
  library(dplyr)
  library(tidyr)
})

'
Aggregate agricultural losses to polygonal boundaries

Usage: wsim_ag_aggregate [options]

Options:
--boundaries <file>   Boundaries over which to aggregate
--id_field <name>     Name of boundary ID field
--prod_i <file>       netCDF file with irrigated production for each crop
--prod_r <file>       netCDF file with rainfed production for each crop
--loss_i <file>       netCDF file with irrigated losses for each crop
--loss_r <file>       netCDF file with rainfed losses for each crop
--output <file>       File to which aggregated results should be written
'->usage

main <- function(raw_args) {
  args <- parse_args(usage, raw_args)
  
  outfile <- tempfile(fileext='.csv')
  idcol <- args$id_field
  
  xx_cmd <- "/home/dbaston/dev/exactextract/cmake-build-release/exactextract"
  xx_args <- c("-p", args$boundaries,
            "-f", args$id_field,
            "-o", outfile,
            "--progress")
  
  crops <- wsim.agriculture::wsim_subcrop_names()
  
  for (method in c('rainfed', 'irrigated')) {
    for (band in seq_along(crops)) {
      xx_args  <- c(xx_args,
                 "-r", sprintf("\"production_%s_%s:NETCDF:%s:production[%d]\"",
                               method, crops[band], ifelse(method=='rainfed', args$prod_r, args$prod_i), band),
                 "-r", sprintf("\"loss_%s_%s:NETCDF:%s:cumulative_loss_current_year[%s]\"",
                               method, crops[band], ifelse(method=='rainfed', args$loss_r, args$loss_i), band),
                 "-s", sprintf("\"sum(production_%s_%s)\"",
                               method, crops[band]),
                 "-s", sprintf("\"weighted_sum(loss_%s_%s,production_%s_%s)\"",
                               method, crops[band], method, crops[band]))
    }
  }
  
  info('Computing zonal statistics')
  ret_code <- system2(xx_cmd, xx_args)
  if (ret_code != 0) {
    die_with_message('exactextract command failed.')
  }
  info('Finished computing zonal statistics')
  
  dat <- read.csv(outfile, stringsAsFactors=FALSE)
  file.remove(outfile)
  
  strtok <- function(x, splitchar, toks) {
    sapply(strsplit(x, splitchar), function(tok) tok[toks])
  }
  
  production <- dat %>%
    dplyr::select(!!rlang::sym(idcol), names(dat)[startsWith(names(dat), 'production')]) %>%
    gather(key='crop_method', value='production', -!!rlang::sym(idcol)) %>%
    mutate(method=strtok(crop_method, '_', 2),
           crop=strtok(crop_method, '_', 3),
           subcrop=suppressWarnings(as.integer(strtok(crop_method, '_', 4)))) %>%
    dplyr::select(!!rlang::sym(idcol), crop, subcrop, method, production)
  
  loss <- dat %>%
    select(!!rlang::sym(idcol), names(dat)[startsWith(names(dat), 'loss')]) %>%
    gather(key='crop_method', value='loss', -!!rlang::sym(idcol)) %>%
    mutate(method=strtok(crop_method, '_', 2),
           crop=strtok(crop_method, '_', 3),
           subcrop=suppressWarnings(as.integer(strtok(crop_method, '_', 4)))) %>%
    select(!!rlang::sym(idcol), crop, method, loss)
    
  overall_loss <- production %>%
    inner_join(loss, by=c(idcol, 'crop', 'method')) %>%
    group_by(!!rlang::sym(idcol), crop) %>%
    summarize(overall_loss=sum(loss)/sum(production),
              overall_production=sum(production)) %>%
    rename(id=!!rlang::sym(idcol)) %>%
    arrange(crop, id)
  
  # Use RDS until write_vars_to_cdf correctly handles multidimensional tabular data.
  saveRDS(overall_loss, args$output)
  infof('Wrote losses to %s', args$output)
    
  #wsim.io::write_vars_to_cdf(overall_loss,
  #                  '/tmp/oloss.nc',
  #                  ids=sort(unique(overall_loss$id)),
  #                  extra_dims=list(crop=sort(unique(overall_loss$crop))))
}

if (!interactive()) {
  tryCatch(
    main(commandArgs(trailingOnly=TRUE))
  ,error=wsim.io::die_with_message)
}