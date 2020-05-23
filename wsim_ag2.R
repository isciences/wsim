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
--calendar <file>    Crop calendar file
--crop 
--model <file>       Random forest model file
--anom <file>        File of standardized anomalies
--yearmon <yearmon>  Year and month of most recent observed anomalies
--output 
'->usage

rf_vars <- c('T_1mo_mean', 'RO_1mo_mean', 'Ws_1mo_mean', 'Bt_RO_1mo_max', 'Pr_1mo_mean', 'PETmE_1mo_mean')
anom_vars <- c('T_sa', 'RO_mm_sa', 'Ws_sa', 'Bt_RO_sa', 'Pr_sa', 'PETmE_sa')

args <- list()

args$anom <- 
  sprintf('/home/dan/wsim/may12/derived/anom/anom_1mo_%s.nc',
          c('201905', '201906', '201907', '201908', '201909', '201910',
            '201911', '201912', '202001', '202002', '202003', '202004',
            '202004_trgt202005_fcstcfsv2_2020043018',
            '202004_trgt202006_fcstcfsv2_2020043018',
            '202004_trgt202007_fcstcfsv2_2020043018',
            '202004_trgt202008_fcstcfsv2_2020043018',
            '202004_trgt202009_fcstcfsv2_2020043018',
            '202004_trgt202010_fcstcfsv2_2020043018',
            '202004_trgt202011_fcstcfsv2_2020043018',
            '202004_trgt202012_fcstcfsv2_2020043018',
            '202004_trgt202101_fcstcfsv2_2020043018'))
args$calendar <- '/home/dan/wsim/may12/source/MIRCA2000/crop_calendar_rainfed.nc'
args$crop <- 'maize'
args$output <- '/tmp/ag_losses.nc'
args$yearmon <- '202005'
args$model <- 'r7_maize_county'


# FIXME need to get correct subcrop
calendar <- read_vars_from_cdf(sprintf('%s::plant_date,harvest_date', args$calendar),
                               extra_dims=list(crop='maize_1'))

# FIXME with a combined model (rainfed/irrigated), what crop calendar should we use?
# check script used to prep data for model fitting.
infof('Read %s crop calendar from %s', args$crop, args$calendar)

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
  
plant_month <- matrix(doy_to_month[calendar$data$plant_date],
                      nrow=nrow(calendar$data$plant_date),
                      ncol=ncol(calendar$data$plant_date))
harvest_month <- matrix(doy_to_month[calendar$data$harvest_date],
                        nrow=nrow(calendar$data$harvest_date),
                        ncol=ncol(calendar$data$harvest_date))

# mxn 
nx <- 720
ny <- 360

months_obs <- 12
months_fcst <- 9
model_months <- 12


month <- as.integer(substr(args$yearmon, 5, 6))

in_season <- abind(sapply(0:11,
                          function(m) is_growing_season(harvest_month - m, plant_month, harvest_month),
                          simplify=FALSE),
                   along=3)

start_indices <- months_until_harvest(month, harvest_month) - model_months + months_obs + 1

flatten_arr <- function(arr, varname) {
  dim(arr) <- c(nx*ny, model_months)
  dimnames(arr) <- list(row=1:(nx*ny),
                        var=sprintf('%s_%s', varname, 0:(model_months-1)))
  arr
}

anom_tbl <- do.call(cbind, lapply(rf_vars, function(rf_var) {
var <- anom_vars[which(rf_vars == rf_var)]

anoms <- lapply(args$anom, function(anom_fname) {
read_vars(sprintf('%s::%s', anom_fname, var))
})

# TODO ensure anoms are sorted
# 
# TODO ensure 12 months of observed data

anoms <- abind(lapply(anoms, function(d) d$data[[1]]), along=3)
anoms <- wsim.lsm::coalesce(anoms, 0)

stack_select(anoms, start_indices, model_months, 0) %>%
flatten_arr(rf_var)
}))

anom_tbl <- cbind(anom_tbl, flatten_arr(in_season, 'in_season'))
anom_tbl <- cbind(anom_tbl, frac_prod_irr=runif(nrow(anom_tbl)))

infof('Read anomalies')

# Subset the inputs to pixels where we have a defined crop calendar.
input <- anom_tbl[!is.na(anom_tbl[, 'in_season_0']), ]

rf <- readRDS(args$model)

infof('Loaded model')

p <- predict(object = rf,
             data = input)

results <- matrix(NA_real_, nrow=ny, ncol=nx)
results[as.integer(dimnames(input)[[1]])] <- p$predictions

write_vars_to_cdf(list(loss=results),
                  args$output,
                  extent=calendar$extent,
                  prec='single')

infof('Wrote preditions to %s', args$output)
