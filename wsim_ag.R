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
library(wsim.lsm)
})

'
Compute crop-specific loss risk

Usage: wsim_ag.R --calendar_irr <file> --calendar_rf <file> --prod_irr <file> --prod_rf <file> --model_spring_wheat <file> --model_winter_wheat <file> --model_maize <file> --model_rice <file> --model_soybeans <file> --model_potatoes <file> --anom <file>... --yearmon <yearmon> --output <file> [--seed <num>]

Options:
--calendar_irr <file>        Crop calendar file
--calendar_rf <file>         Crop calendar file
--prod_irr <file>            Irrigated production
--prod_rf <file>             Rainfed production
--model_spring_wheat <file>  Random forest model file for spring wheat
--model_winter_wheat <file>  Random forest model file for winter wheat
--model_maize <file>         Random forest model file for maize
--model_soybeans <file>      Random forest model file for soybeans
--model_potatoes <file>      Random forest model file for potatoes
--model_rice <file>          Random forest model file for rice
--anom <file>                File of standardized anomalies
--yearmon <yearmon>          Year and month of most recent observed anomalies
--seed <num>                 Optional seed for random anomaly generation outside forecast period
--output <file>
'->usage

# test args
test_args <- list()

test_args$yearmon <- '202004'
test_args$anom <- c(
  sprintf('/home/dan/wsim/may12/derived/anom/anom_1mo_[%s:%s].nc', add_months(test_args$yearmon, -23), test_args$yearmon),
  sprintf('/home/dan/wsim/may12/derived/anom/anom_1mo_%s_trgt[%s:%s]_fcstcfsv2_%s3018.nc',
          test_args$yearmon,
          add_months(test_args$yearmon, 1),
          add_months(test_args$yearmon, 9),
          test_args$yearmon)
)

#args$anom <-
#  sprintf('/home/dan/wsim/may12/derived/anom/anom_1mo_%s.nc',
#          c('201905', '201906', '201907', '201908', '201909', '201910',
#            '201911', '201912', '202001', '202002', '202003', '202004',
#            '202004_trgt202005_fcstcfsv2_2020043018',
#            '202004_trgt202006_fcstcfsv2_2020043018',
#            '202004_trgt202007_fcstcfsv2_2020043018',
#            '202004_trgt202009_fcstcfsv2_2020043018',
#            '202004_trgt202008_fcstcfsv2_2020043018',
#            '202004_trgt202010_fcstcfsv2_2020043018',
#            '202004_trgt202011_fcstcfsv2_2020043018',
#            '202004_trgt202012_fcstcfsv2_2020043018',
#            '202004_trgt202101_fcstcfsv2_2020043018'))
test_args$prod_irr <- '/home/dan/wsim/may12/source/SPAM2010/production_irrigated.nc'
test_args$prod_rf <- '/home/dan/wsim/may12/source/SPAM2010/production_rainfed.nc'
test_args$calendar_rf <- '/home/dan/wsim/may12/source/MIRCA2000/crop_calendar_rainfed.nc'
test_args$calendar_irr <- '/home/dan/wsim/may12/source/MIRCA2000/crop_calendar_irrigated.nc'
test_args$output <- '/tmp/ag_losses.nc'
test_args$model_maize <-        '/home/dan/wsim/may12/source/ag_models/r7_maize.rds'
test_args$model_rice <-         '/home/dan/wsim/may12/source/ag_models/r7_rice.rds'
test_args$model_winter_wheat <- '/home/dan/wsim/may12/source/ag_models/r7_winter_wheat.rds'
test_args$model_spring_wheat <- '/home/dan/wsim/may12/source/ag_models/r7_spring_wheat.rds'
test_args$model_soybeans <-     '/home/dan/wsim/may12/source/ag_models/r7_soybeans.rds'
test_args$model_potatoes <-     '/home/dan/wsim/may12/source/ag_models/r7_potatoes.rds'

# globals
rf_vars <- c('T_1mo_mean', 'RO_1mo_mean', 'Ws_1mo_mean', 'Bt_RO_1mo_max', 'Pr_1mo_mean', 'PETmE_1mo_mean')
anom_vars <- c('T_sa', 'RO_mm_sa', 'Ws_sa', 'Bt_RO_sa', 'Pr_sa', 'PETmE_sa')
model_months <- 12

# utility functions (move to pkg)

is_growing_season <- function(month, plant_month, harvest_month) {
  ifelse(harvest_month > plant_month,
         month >= plant_month & month <= harvest_month,
         month >= plant_month | month <= harvest_month)
}


months_until_harvest_this_year <- function(month, harvest_month) {
  harvest_month - month
}

months_until_harvest_next_year <- function(month, harvest_month) {
  harvest_month - month + 12L
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

subcrop_model_name <- function(subcrop) {
  if (subcrop == 'wheat_1') {
    'winter_wheat'
  } else if (subcrop == 'wheat_2') {
    'spring_wheat'
  } else {
    sub('_\\d+$', '', subcrop)
  }
}

main <- function(raw_args) {
  args <- wsim.io::parse_args(usage, raw_args)

  anoms <- read_anoms(anom_vars, wsim.io::expand_inputs(args$anom))
  anom_yearmons <- dimnames(anoms[[1]])[[3]]
  months_obs <- sum(anom_yearmons <= args$yearmon)
  months_fcst <- sum(anom_yearmons > args$yearmon)
  infof('Read %d months of anomalies (%d observed, %d forecast)',
        length(anom_yearmons), months_obs, months_fcst)

  if (!is.null(args$seed)) {
    set.seed(as.integer(args$seed))
    anomaly_fill <- function() { rnorm(1) }
    infof('Forecast anomalies with > %d-month lead will be filled with random values (seed = %s)', months_fcst, args$seed)
  } else {
    infof('Forecast anomalies with > %d-month lead will be filled with zero', months_fcst)
    anomaly_fill <- 0
  }


  nx <- dim(anoms[[1]])[2]
  ny <- dim(anoms[[1]])[1]

  subcrops <- wsim.agriculture::wsim_subcrop_names()

  # initialize results array
  results <- list()
  for (harvest in c('current_year', 'next_year')) {
    results[[harvest]] <- array(NA, dim=c(ny, nx, length(subcrops)))
    dimnames(results[[harvest]])[[3]] <- subcrops
  }

  last_subcrop_model_fname <- ''

  for (subcrop in subcrops) {
    infof('Processing %s', subcrop)

    subcrop_model_fname <- args[[sprintf('model_%s', subcrop_model_name(subcrop))]]

    # avoid reading same model when it is shared between subcrops
    if (subcrop_model_fname != last_subcrop_model_fname) {
      infof('Reading model from %s', subcrop_model_fname)
      rf <- readRDS(subcrop_model_fname)
      last_subcrop_model_fname <- subcrop_model_fname
      infof('Loaded model from %s', subcrop_model_fname)
    }

    calendar_irr <- read_vars_from_cdf(args$calendar_irr,
                                       vars=c('plant_date', 'harvest_date'), #sprintf('%s::plant_date,harvest_date', args$calendar),
                                       extra_dims=list(crop=subcrop))

    calendar_rf <- read_vars_from_cdf(args$calendar_rf,
                                       vars=c('plant_date', 'harvest_date'), #sprintf('%s::plant_date,harvest_date', args$calendar),
                                       extra_dims=list(crop=subcrop))
    infof('Read crop calendars for %s', subcrop)

    # TODO read in subcrop area fraction and null out the calendar if it is zero

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

    plant_month <- doy_to_month(plant_date)
    harvest_month <- doy_to_month(harvest_date)

    in_season <- abind(sapply(0:11,
                              function(m) is_growing_season(harvest_month - m, plant_month, harvest_month),
                              simplify=FALSE),
                       along=3)

    month <- as.integer(substr(args$yearmon, 5, 6))

    for (harvest in c('current_year', 'next_year')) {
      if (harvest == 'current_year') {
        start_indices <- anomaly_start_indices(months_until_harvest_this_year(month, harvest_month),
                                               model_months,
                                               months_obs)
      } else {
        start_indices <- anomaly_start_indices(months_until_harvest_next_year(month, harvest_month),
                                               model_months,
                                               months_obs)
      }

      infof('Arranging anomalies for the %s crop calendar', subcrop)
      anom_tbl <- do.call(cbind, lapply(rf_vars, function(rf_var) {
        anom_var <- anom_vars[which(rf_vars == rf_var)]

        anoms[[anom_var]] %>%
          stack_select(start_indices, model_months, anomaly_fill) %>%
          flatten_arr() %>%
          stats::pnorm() %>% # convert standardized anomaly to probability (0-1)
          set_dimnames(2, paste(rf_var, 11:0, sep='_'))
      }))

      anom_tbl <- cbind(anom_tbl, flatten_arr(in_season) %>%
                          set_dimnames(2, paste('in_season', 11:0, sep='_')))
      anom_tbl <- cbind(anom_tbl, frac_prod_irr=as.vector(prod_frac_irr))

      # Subset the inputs to pixels where we have a defined crop calendar.
      # Store the original row numbers as dimnames so that we can match
      # outputs to inputs.
      dimnames(anom_tbl)[[1]] <- 1:nrow(anom_tbl)
      input <- anom_tbl[!is.na(anom_tbl[, 'in_season_0']), ]

      infof('Generating yield anomaly predictions for %s (harvest %s)', subcrop, sub('_', ' ', harvest))
      p <- predict(object = rf, data = input)

      q <- matrix(NA_real_, nrow=ny, ncol=nx)
      q[as.integer(dimnames(input)[[1]])] <- p$predictions
      results[[harvest]][,,subcrop] <- q

      gc()
    }

  }

  write_vars_to_cdf(list(yield_frac_current_year=results[['current_year']],
                         yield_frac_next_year=results[['next_year']]),
                    args$output,
                    extent=calendar_irr$extent,
                    extra_dims=list(crop=subcrops),
                    prec='single')

  infof('Wrote predictions to %s', args$output)
}

if (!interactive()) {
  tryCatch(
    main(commandArgs(trailingOnly=TRUE))
  ,error=wsim.io::die_with_message)
}
