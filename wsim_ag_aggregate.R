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

parse_quantiles <- function(varnames) {
  sort(unique(as.integer(regmatches(varnames,
                             regexpr('(?<=)\\d+$', varnames, perl=TRUE)))))
}

main <- function(raw_args) {
  args <- parse_args(usage, raw_args)

  outfile <- tempfile(fileext='.csv')
  idcol <- args$id_field

  xx_cmd <- "exactextract"
  xx_args <- c("-p", args$boundaries,
            "-f", args$id_field,
            "-o", outfile)

  crops <- wsim.agriculture::wsim_subcrop_names()
  
  # Probe the loss files to see if losses are expressed as quantiles
  loss_quantiles <- parse_quantiles(wsim.io::read_varnames(args$loss_i))
  if (length(loss_quantiles) > 0) {
    wsim.io::info('Inputs appear to be available at the following quantiles:', loss_quantiles)
  }

  prod_rasters <- list(
    rainfed= args$prod_r,
    irrigated= args$prod_i
  )

  loss_rasters <- list(
    rainfed= args$loss_r,
    irrigated= args$loss_i
  )

  for (method in c('rainfed', 'irrigated')) {
    for (band in seq_along(crops)) {
      xx_args  <- c(xx_args,
                 "-r", sprintf("\"production_%s_%s:NETCDF:%s:production[%d]\"",
                               method, crops[band], prod_rasters[[method]], band),
                 "-s", sprintf("\"production_%s_%s=sum(production_%s_%s)\"",
                               method, crops[band], method, crops[band]))

      if (length(loss_quantiles) == 0) {
        xx_args <- c(xx_args,
                 "-r", sprintf("\"loss_%s_%s:NETCDF:%s:cumulative_loss_current_year[%d]\"",
                               method, crops[band], loss_rasters[[method]], band),
                 "-s", sprintf("\"loss_%s_%s=weighted_sum(loss_%s_%s,production_%s_%s)\"",
                               method, crops[band], method, crops[band], method, crops[band]))
      } else {
        for (q in loss_quantiles) {
          xx_args <- c(xx_args,
                   "-r", sprintf("\"loss_%s_%s_q%d:NETCDF:%s:cumulative_loss_current_year_q%d[%d]\"",
                                 method, crops[band], q, loss_rasters[[method]], q, band),
                   "-s", sprintf("\"loss_%s_%s_q%d=weighted_sum(loss_%s_%s_q%d,production_%s_%s)\"",
                                 method, crops[band], q, method, crops[band], q, method, crops[band]))
        }
      }
    }
  }

  info('Computing zonal statistics')
  ret_code <- system2(xx_cmd, xx_args)
  if (ret_code != 0) {
    die_with_message('exactextract command failed.')
  }
  info('Finished computing zonal statistics')
  
  dat <- wsim.agriculture::parse_exactextract_results(outfile)
  file.remove(outfile)
  
  system.time(summarized <- wsim.agriculture::summarize_loss(dat$production, dat$loss))
  
  wsim.io::write_vars_to_cdf(wsim.agriculture::format_loss_by_crop(summarized$by_crop),
                             args$output,
                             ids=sort(unique(summarized$by_crop$id)),
                             extra_dims=list(crop=sort(unique(summarized$by_crop$crop))),
                             prec='single')
  infof('Wrote per-crop aggregated results to %s', args$output)
  
  the_rest <- dplyr::inner_join(
    wsim.agriculture::format_loss_by_type(summarized$by_type),
    wsim.agriculture::format_overall_loss(summarized$overall),
    by='id')
  
  wsim.io::write_vars_to_cdf(the_rest,
                             args$output,
                             ids=sort(unique(the_rest$id)),
                             prec='single',
                             append=TRUE)
  infof('Wrote overall results to %s', args$output)
}

if (!interactive()) {
  tryCatch(
    main(commandArgs(trailingOnly=TRUE))
  ,error=wsim.io::die_with_message)
}
