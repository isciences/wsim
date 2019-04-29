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

  argfile <- tempfile()
  outfile <- tempfile(fileext='.csv')
  idcol <- args$id_field

  xx_cmd <- "exactextract"
  xx_args <- list(
    polygons= args$boundaries,
    fid= args$id_field,
    output= outfile,
    raster= NULL,
    stat=NULL
  )

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

  loss_vars <-c('cumulative_loss_current_year', 'cumulative_loss_next_year', 'loss')

  for (method in c('rainfed', 'irrigated')) {
    for (band in seq_along(crops)) {
      xx_args$raster <- c(xx_args$raster,
                          sprintf("\"production_%s_%s:NETCDF:%s:production[%d]\"",
                                  method, crops[band], prod_rasters[[method]], band))
      xx_args$stat <- c(xx_args$stat,
                        sprintf("\"production_%s_%s=sum(production_%s_%s)\"",
                                method, crops[band], method, crops[band]))

      for (varname in loss_vars) {
        if (length(loss_quantiles) == 0) {
          xx_args$raster <- c(xx_args$raster,
                              sprintf("\"%s_%s_%s:NETCDF:%s:%s[%d]\"",
                                      varname, method, crops[band], # raster name
                                      loss_rasters[[method]],       # raster filename
                                      varname, band))               # netCDF variable name and crop band
          xx_args$stat <- c(xx_args$stat,
                            sprintf("\"%s_%s_%s=weighted_sum(%s_%s_%s,production_%s_%s)\"",
                                    varname, method, crops[band], # output variable name
                                    varname, method, crops[band], # input loss variable (first stat arg)
                                    method, crops[band]))         # input production variable (second stat arg)
        } else {
          for (q in loss_quantiles) {
            xx_args$raster <- c(xx_args$raster,
                                sprintf("\"%s_%s_%s_q%d:NETCDF:%s:%s_q%d[%d]\"",
                                        varname, method, crops[band], q, # raster name
                                        loss_rasters[[method]],          # raster filename
                                        varname, q, band))               # netCDF variable name and crop band
            xx_args$stat <- c(xx_args$stat,
                              sprintf("\"%s_%s_%s_q%d=weighted_sum(%s_%s_%s_q%d,production_%s_%s)\"",
                                      varname, method, crops[band], q, # output variable name
                                      varname, method, crops[band], q, # input loss variable (first stat arg)
                                      method, crops[band]))            # input production variable (second stat arg)
          }
        }
      }
    }
  }

  # Write arguments to a file and direct exactextract to read configuration from this file.
  # This is to work around an apparent limitation (maybe with system2?) on command-line length that is lower than the OS limitation.
  writeLines(sapply(names(xx_args), function(arg)
    sprintf('%s = %s', arg, paste(xx_args[[arg]], collapse=' '))),
    argfile)

  info('Computing zonal statistics')
  ret_code <- system2(xx_cmd,
                      args=c('--config', argfile),
                      env=c('GDAL_NETCDF_VERIFY_DIMS=NO', # Disable warning that "crop" dimension is not a time or vertical dimension
                            'CPL_LOG=NO'))                # Disable _ALL_ GDAL warnings/errors. Unfortunately there doesn't seem to be
                                                          # a way to disable only warnings, or the spurious warning produced by having a
                                                          # character-array dimension variable.
  if (ret_code != 0) {
    die_with_message('exactextract command failed with return code', ret_code)
  }
  info('Finished computing zonal statistics')

  dat <- wsim.agriculture::parse_exactextract_results(outfile, c('production', loss_vars))
  file.remove(outfile)
  file.remove(argfile)

  summarized <- lapply(loss_vars, function(v)
    wsim.agriculture::summarize_loss(dplyr::select(dat$production, -quantile), dat[[v]], v))
  names(summarized) <- loss_vars

  by_crop <- Reduce(function(x, y) dplyr::inner_join(x, y, by=c('id', 'crop')),
                    lapply(loss_vars, function(v) wsim.agriculture::format_loss_by_crop(summarized[[v]]$by_crop, v)))

  wsim.io::write_vars_to_cdf(by_crop,
                             args$output,
                             ids=sort(unique(by_crop$id)),
                             extra_dims=list(crop=sort(unique(by_crop$crop))),
                             prec='single')
  infof('Wrote per-crop aggregated results to %s', args$output)

  the_rest <- Reduce(function(x, y) dplyr::inner_join(x, y, by='id'),
                     c(lapply(loss_vars, function(v) wsim.agriculture::format_loss_by_type(summarized[[v]]$by_type, v)),
                       lapply(loss_vars, function(v) wsim.agriculture::format_overall_loss(summarized[[v]]$overall, v))))

  wsim.io::write_vars_to_cdf(the_rest,
                             args$output,
                             ids=sort(unique(the_rest$id)),
                             prec='single',
                             append=TRUE)
  infof('Wrote overall results to %s', args$output)
}

if (!interactive()) {
#  tryCatch(
    main(commandArgs(trailingOnly=TRUE))
#  ,error=wsim.io::die_with_message)
}
