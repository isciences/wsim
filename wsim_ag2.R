#!/usr/bin/env Rscript

# Copyright (c) 2020 ISciences, LLC.
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


wsim.io::logging_init('wsim_ag')
suppressMessages({
library(Rcpp)
library(abind)
library(dplyr)
library(ranger)
library(tidyr)
library(wsim.agriculture)
library(wsim.distributions)
library(wsim.io)
})

'
Compute crop-specific loss risk

Usage: wsim_ag.R --calendar <file> --anom <file>... --yearmon <yyyymm> --model <file>

Options:
--calendar_irr <file>    Crop calendar file
--calendar_rf <file>    Crop calendar file
--subcrop <name>     Name of subcrop to process (e.g., maize_1, rice_4)
--prod_irr <file>    Irrigated production
--prod_rf  <file>    Rainfed production
--model <file>       Random forest model file
--anom <file>        File of standardized anomalies
--yearmon <yearmon>  Year and month of most recent observed anomalies
--output 
'->usage

# test args
args <- list()

args$anom <- 
  sprintf('/home/dan/wsim/may12/derived/anom/anom_1mo_%s.nc',
          c('201905', '201906', '201907', '201908', '201909', '201910',
            '201911', '201912', '202001', '202002', '202003', '202004',
            '202004_trgt202005_fcstcfsv2_2020043018',
            '202004_trgt202006_fcstcfsv2_2020043018',
            '202004_trgt202007_fcstcfsv2_2020043018',
            '202004_trgt202009_fcstcfsv2_2020043018',
            '202004_trgt202008_fcstcfsv2_2020043018',
            '202004_trgt202010_fcstcfsv2_2020043018',
            '202004_trgt202011_fcstcfsv2_2020043018',
            '202004_trgt202012_fcstcfsv2_2020043018',
            '202004_trgt202101_fcstcfsv2_2020043018'))
args$prod_irr <- '/home/dan/wsim/may12/source/SPAM2010/production_irrigated.nc'
args$prod_rf <- '/home/dan/wsim/may12/source/SPAM2010/production_rainfed.nc'
args$calendar_rf <- '/home/dan/wsim/may12/source/MIRCA2000/crop_calendar_rainfed.nc'
args$calendar_irr <- '/home/dan/wsim/may12/source/MIRCA2000/crop_calendar_irrigated.nc'
args$crop <- 'maize'
args$output <- '/tmp/ag_losses.nc'
args$yearmon <- '202004'
args$model <- '/home/dan/dev/wsim/r7_maize_county'

# globals
rf_vars <- c('T_1mo_mean', 'RO_1mo_mean', 'Ws_1mo_mean', 'Bt_RO_1mo_max', 'Pr_1mo_mean', 'PETmE_1mo_mean')
anom_vars <- c('T_sa', 'RO_mm_sa', 'Ws_sa', 'Bt_RO_sa', 'Pr_sa', 'PETmE_sa')
model_months <- 12

# utility functions (move to pkg)
doy_to_month <- sapply(1:365,
                       function(doy) {
                         as.integer(strftime(as.Date(doy - 1, origin='1999-01-01'), '%m'))
                       })

is_growing_season <- function(month, plant_month, harvest_month) {
  ifelse(harvest_month > plant_month,
         month >= plant_month & month <= harvest_month,
         month >= plant_month | month <= harvest_month)
}

months_until_harvest <- function(month, harvest_month) {
  ifelse(harvest_month - month < 0,
         harvest_month - month + 12L,
         harvest_month - month)
}

#' Reduce the dimensions of a 3-dimensional array
#' 
#' The first two dimensions will be combined, while the third dimension will be preserved.
#' 
#' @param arr array to flatten
#' @param varname 
flatten_arr <- function(arr) {
  dim(arr) <- c(prod(dim(arr)[1:2]), dim(arr)[3])
  dimnames(arr) <- list(row=1:dim(arr)[1],
                        col=1:dim(arr)[2])
  arr
}

set_dimnames <- function(x, dim, names) {
  dimnames(x)[[dim]] <- names
  x
}

update_dimnames <- function(x, dim, fun) {
  set_dimnames(x, dim, fun(dimnames(x)[[dim]]))
}

#' Read anom_vars from fnames
#' Return a list with a 3d array for each anom_var
#' Dates associated with each anomaly are provided in dimnames of cube
#' NA anomalies replaced with zero
read_anoms <- function(anom_vars, fnames) {
  anoms <- sapply(anom_vars, function(anom_var) {
    a <- list()
    for (anom_fname in fnames) {
      d <- read_vars_from_cdf(anom_fname, vars=anom_var)
      target <- d[['attrs']][['target']]
      a[[target]] <- wsim.lsm::coalesce(d$data[[1]], 0)
    }
    abind::abind(a[sort(names(a))], along=3)
  }, simplify = FALSE)
  
  dates <- dimnames(anoms)[[3]]
  if (!all(dates[-1] == sapply(dates, wsim.lsm::next_yyyymm)[-length(dates)])) {
    stop('Provided anomaly files do not form a contiguous sequence.')
  }

  return(anoms)
}

#flatten_arr <- function(arr, varname) {
#  dim(arr) <- c(nx*ny, model_months)
#  dimnames(arr) <- list(row=1:(nx*ny),
#                        var=sprintf('%s_%s', varname, 0:(model_months-1)))
#  arr
#}

main <- function(raw_args) {
  #args <- wsim.io::parse_args(usage, raw_args)
  
  infof('Reading model from %s', args$model)
  rf <- readRDS(args$model)
  infof('Loaded model from %s', args$model)
  
  anoms <- read_anoms(anom_vars, args$anom)
  anom_yearmons <- dimnames(anoms[[1]])[[3]]
  # TODO use yearmon/target attrs from anomaly files to determine args$yearmon
  # instead of relying on user input?
  months_obs <- sum(anom_yearmons <= args$yearmon)
  months_fcst <- sum(anom_yearmons > args$yearmon)
  infof('Read %d months of anomalies (%d observed, %d forecast)', 
        length(anom_yearmons), months_obs, months_fcst)
  
  num_subcrops <- wsim.agriculture::wsim_crops %>%
    filter(wsim_name == args$crop) %>%
    inner_join(wsim.agriculture::mirca_crops, by='wsim_id') %>%
    pull(mirca_subcrops)
  
  for (subcrop in wsim.agriculture::subcrop_names(args$crop, num_subcrops)) {
    calendar_irr <- read_vars_from_cdf(args$calendar_irr,
                                       vars=c('plant_date', 'harvest_date'), #sprintf('%s::plant_date,harvest_date', args$calendar),
                                       extra_dims=list(crop=subcrop))
    
    calendar_rf <- read_vars_from_cdf(args$calendar_rf,
                                       vars=c('plant_date', 'harvest_date'), #sprintf('%s::plant_date,harvest_date', args$calendar),
                                       extra_dims=list(crop=subcrop))
    infof('Read crop calendars for %s', subcrop)
    
    prod_irr <- wsim.io::read_vars_from_cdf(args$prod_irr,
                                                 vars='production',
                                                 extra_dims=list(crop=subcrop))$data[[1]]
    prod_rf <- wsim.io::read_vars_from_cdf(args$prod_rf,
                                                vars='production',
                                                extra_dims=list(crop=subcrop))$data[[1]]
    
    infof('Read production data for %s', subcrop)
    
    prod_frac_irr <- aggregate_mean(prod_irr / psum(prod_irr, prod_rf), 6)
    infof('Computed irrigated fraction for %s', subcrop)
    
    plant_date <- ifelse(prod_frac_irr >= 0.5,
                         calendar_irr$data$plant_date,
                         calendar_rf$data$plant_date)
    harvest_date <- ifelse(prod_frac_irr >= 0.5,
                         calendar_irr$data$harvest_date,
                         calendar_rf$data$harvest_date)
    
    infof('Computed dominant calendar for %s based on dominant cultivation method', subcrop)
  
    # todo pull into a method, use s3 dispatch to preserve matrix dims?
    plant_month <- matrix(doy_to_month[plant_date],
                          nrow=nrow(plant_date),
                          ncol=ncol(plant_date))
    harvest_month <- matrix(doy_to_month[harvest_date],
                            nrow=nrow(harvest_date),
                            ncol=ncol(harvest_date))
    
    in_season <- abind(sapply(0:11,
                              function(m) is_growing_season(harvest_month - m, plant_month, harvest_month),
                              simplify=FALSE),
                       along=3)
  
    month <- as.integer(substr(args$yearmon, 5, 6))
    start_indices <- months_until_harvest(month, harvest_month) - model_months + months_obs + 1
    nx <- dim(start_indices)[2]
    ny <- dim(start_indices)[1]
    
    anom_tbl <- do.call(cbind, lapply(rf_vars, function(rf_var) {
      anom_var <- anom_vars[which(rf_vars == rf_var)]
      
      anom_arr <- flatten_arr(stack_select(anoms[[anom_var]], start_indices, model_months, 0)) %>%
        update_dimnames(2, function(n) paste(rf_var, as.integer(n) - 1, sep='_'))
    }))
    
    anom_tbl <- cbind(anom_tbl, flatten_arr(in_season) %>%
                        update_dimnames(2, function(n) paste('in_season', as.integer(n) - 1, sep='_')))
    anom_tbl <- cbind(anom_tbl, frac_prod_irr=as.vector(prod_frac_irr))
    
    infof('Read anomalies')
    
    # Subset the inputs to pixels where we have a defined crop calendar.
    input <- anom_tbl[!is.na(anom_tbl[, 'in_season_0']), ]
    
    p <- predict(object = rf, data = input)
    
    results <- matrix(NA_real_, nrow=ny, ncol=nx)
    results[as.integer(dimnames(input)[[1]])] <- p$predictions
    
    write_vars_to_cdf(list(loss=results),
                      args$output,
                      extent=calendar_irr$extent,
                      prec='single')
    
    infof('Wrote predictions to %s', args$output)
  }
}

main()


