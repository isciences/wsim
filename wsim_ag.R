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

wsim.io::logging_init('wsim_ag')
suppressMessages({
  require(Rcpp)
  require(wsim.io)
  require(wsim.agriculture)
})

'
Compute crop-specific loss risk

Usage: wsim_ag --state <file> --surplus <file>... --deficit <file>... --temperature_rp <file> --calendar <file> --loss_factors <file> --next_state <file> --results <file> --yearmon <yearmon> [--extra_output <file>]

Options:
--state <file>           Previous state
--surplus <file>         Return period of one or more variables associated with surplus
--deficit <file>         Return period of one or more variables associated with deficit
--extra_output <file>    Optional file to which intermediate calculations can be saved
--temperature_rp <file>  Surface temperature return period
--calendar <file>        Crop calendar file
--loss_factors <file>    Loss factor csv
--next_state <file>      output file
--results <file>         output file
--yearmon <yearmon>      yearmon
'->usage

stress_threshold <- 30
stresses <- c('surplus', 'deficit', 'heat', 'cold')
methods <- c('irrigated', 'rainfed')

test_args <- list(
  '--state',          '/home/dbaston/wsim/oct22/agriculture/state_rainfed/state_201001.nc',
  '--next_state',     '/home/dbaston/wsim/oct22/agriculture/state_rainfed/state_201002.nc',
  '--results',        '/home/dbaston/wsim/oct22/agriculture/results_rainfed/results_1mo_201001.nc',
  #'--extra_output',   '/home/dbaston/wsim/oct22/agriculture/results_rainfed/extra_output_1mo_201001.nc',
  '--surplus',        '/home/dbaston/wsim/oct22/rp/rp_1mo_201001.nc::RO_mm_rp',
  '--deficit',        '/home/dbaston/wsim/oct22/rp/rp_1mo_201001.nc::PETmE_rp,Ws_rp',
  #'--deficit',        '/home/dbaston/wsim/oct22/agriculture/bt_ro_rp/bt_ro_rp_201003.nc',
  '--temperature_rp', '/home/dbaston/wsim/oct22/rp/rp_1mo_201001.nc::T_rp',
  '--calendar',       '/mnt/fig_rw/WSIM_DEV/source/MIRCA2000/crop_calendar_rainfed.nc',
  '--loss_factors',   '/tmp/factors.csv',
  '--yearmon',        '201001'
)

clamp <- function(vals, minval, maxval) {
  pmax(pmin(vals, maxval), minval)
}

main <- function(raw_args) {
  args <- wsim.io::parse_args(usage, raw_args)

  surpluses <- wsim.io::read_vars_to_cube(args$surplus)
  wsim.io::info('Read surplus values:', paste(dimnames(surpluses)[[3]], collapse=", "))
  surplus <- clamp(wsim.distributions::stack_max(surpluses), -60, 60)
  extent <- attr(surpluses, 'extent')
  rm(surpluses)

  deficits <- wsim.io::read_vars_to_cube(args$deficit)
  wsim.io::info('Read deficit values:', paste(dimnames(deficits)[[3]], collapse=", "))
  stopifnot(all(extent == attr(deficits, 'extent')))
  deficit <- -1*clamp(wsim.distributions::stack_min(deficits), -60, 60)
  rm(deficits)

  stopifnot(dim(surplus) == dim(deficit))

  heat <- wsim.io::read_vars(args$temperature_rp,
                             expect.nvars=1,
                             expect.dims=dim(surplus),
                             expect.extent=extent)$data[[1]]

  cold <- (-heat)

  rp <- list(
    surplus=surplus,
    deficit=deficit,
    heat=heat,
    cold=cold
  )

  res <- c(extent[4]-extent[3], extent[2]-extent[1]) / dim(surplus)

  infof('Initializing state file at %s.', args$next_state, res[1],res[2])
  if (file.exists(args$next_state)) {
    file.remove(args$next_state)
  }
  write_empty_state(fname=args$next_state,
                    res=res,
                    extent=extent,
                    stresses=stresses,
                    fill_zero=FALSE)

  infof('Initializing results file at %s.', args$results)
  if (file.exists(args$results)) {
    file.remove(args$results)
  }
  write_empty_results(fname=args$results,
                      res=res,
                      extent=extent,
                      fill_zero=FALSE)
  
  if (!is.null(args$extra_output)) {
    infof('Initializing extra output file at %s.', args$extra_output)
    write_empty_results(fname=args$extra_output,
                        res=res,
                        extent=extent,
                        vars=c('surplus', 'deficit', 'heat', 'cold', 'rp_surplus', 'rp_deficit', 'rp_temp'),
                        fill_zero=FALSE)
  }

  # TODO forgo argument and just pull table from module?
  #loss_factors <- read.table(args$loss_factors, header=TRUE, sep='\t')
  loss_factors <- wsim.agriculture::example_crop_factors

  month <- as.integer(substr(args$yearmon, 5, 6))
  
  from <- start_of_month(month)
  to <- end_of_month(month)
  days_in_month <- to - from + 1
  
  for (crop in wsim_subcrop_names()) {
    base_crop <- strsplit(crop, '_')[[1]][1]

    # if (crop != 'maize_1')
    # next

    calendar <- read_vars_from_cdf(args$calendar,
                                   extra_dims=list(crop=crop))

    plant_date <- calendar$data$plant
    harvest_date <- calendar$data$harvest

    # How many days of growth did we have this month, considering only the second growing season
    # in cases where this month spanned the end of an old growing season and the start of a
    # new one.
    gd <- list(
      this_year= growing_days_this_year(from, to, plant_date, harvest_date),
      next_year= growing_days_next_year(from, to, plant_date, harvest_date))
    
    # sanity check growing days
    stopifnot(all(is.na(gd$this_year) | (gd$this_year >= 0 & gd$this_year <= days_in_month)))
    stopifnot(all(is.na(gd$next_year) | (gd$next_year >= 0 & gd$next_year <= days_in_month)))
    
    days_since_planting <-
      list(this_year= days_since_planting_this_year(1, to, plant_date, harvest_date),
           next_year= days_since_planting_next_year(1, to, plant_date, harvest_date))

    # Growing days should then be defined wherever calendar is defined.
    stopifnot(all(is.na(gd$this_year) == is.na(plant_date)))
    stopifnot(all(is.na(gd$next_year) == is.na(plant_date)))

    losses <- list()
    for (stress in stresses) {
      early_losses <- loss_factors[loss_factors$crop==base_crop & loss_factors$days > 0, c('days', stress)]
      late_losses  <- loss_factors[loss_factors$crop==base_crop & loss_factors$days < 0, c('days', stress)]

      months_stress <- read_vars_from_cdf(sprintf('%s::months_stress', args$state),
                                          extra_dims=list(crop=crop, stress=stress))$data[[1]]
      
      rp_coalesced <- wsim.lsm::coalesce(rp[[stress]], 0)
      base_loss <- loss_function(rp_coalesced, 12, 80, 2)
      
      loss <- list(
        this_year= base_loss*1, #growth_stage_loss_multiplier(from + 0.5*gd$this_year,
                                #                         plant_date,
                                #                         harvest_date,
                                #                         early_losses,
                                #                         late_losses),
        next_year= base_loss*1  #growth_stage_loss_multiplier(to - 0.5*gd$next_year,
                                #                         plant_date,
                                #                         harvest_date,
                                #                         early_losses,
                                )#                         late_losses))
      
      high_stress <- rp_coalesced > stress_threshold 
      
      # Update consecutive months of stress. Reset the counter if we begin a new growing season.
      # We carry stress forward unless there was a planting in the current month (identified by days_since_planting <= days_in_month)
      mstress <- list(
        this_year= high_stress*(months_stress*!planted_for_this_year(from, to, plant_date, harvest_date) + gd$this_year/30),
        next_year= high_stress*(months_stress*!planted_for_next_year(from, to, plant_date, harvest_date) + gd$next_year/30)
      ) 
      
      #loss$this_year <- loss$this_year * duration_loss_multiplier(mstress$this_year)
      #loss$next_year <- loss$next_year * duration_loss_multiplier(mstress$next_year)
      
      losses[[stress]] <- loss
      
      write_vars_to_cdf(list(months_stress=ifelse(mstress$next_year > 0, mstress$next_year, mstress$this_year)),
                        args$next_state,
                        extent=extent,
                        write_slice=list(crop=crop, stress=stress),
                        append=TRUE,
                        quick_append=TRUE)
    }
    
    loss$this_year <- pmin(wsim.distributions::stack_sum(abind::abind(
      lapply(losses, function(l) l$this_year), along=3)), 1.0) 
    
    loss$next_year <- pmin(wsim.distributions::stack_sum(abind::abind(
      lapply(losses, function(l) l$next_year), along=3)), 1.0) 
    
    # sanity check losses
    stopifnot(all(is.na(loss$this_year) | (loss$this_year >= 0 & loss$this_year <= 1)))
    stopifnot(all(is.na(loss$next_year) | (loss$next_year >= 0 & loss$next_year <= 1)))
    
    prev_state <- read_vars_from_cdf(sprintf('%s::%s', args$state, paste('loss_days_current_year',
                                                                         'loss_days_next_year',
                                                                         'fraction_remaining_current_year',
                                                                         'fraction_remaining_next_year',
                                                                         sep=',')),
                                     extra_dims=list(crop=crop))$data

    
    next_state <- update_crop_state(prev_state, gd, days_in_month, loss,
                                    reset = (month==1),
                                    winter_growth = (harvest_date < plant_date))
    
    # state variables are defined wherever calendars are
    stopifnot(all(is.na(plant_date) == is.na(next_state$fraction_remaining_current_year)))
    stopifnot(all(is.na(plant_date) == is.na(next_state$fraction_remaining_next_year)))
    stopifnot(all(is.na(plant_date) == is.na(next_state$loss_days_current_year)))
    stopifnot(all(is.na(plant_date) == is.na(next_state$loss_days_next_year)))

    growing_season_loss <- list(
      this_year= ifelse(days_since_planting$this_year > 0, next_state$loss_days_current_year / days_since_planting$this_year, NA),
      next_year= ifelse(days_since_planting$next_year > 0, next_state$loss_days_next_year    / days_since_planting$next_year, NA)
    )
    
    loss$this_year[is.na(gd$this_year) | gd$this_year < 1] <- NA
    loss$next_year[is.na(gd$next_year) | gd$next_year < 1] <- NA # Set loss to NA wherever there was no growth
        
    infof('Writing next state for %s', crop) 
    write_vars_to_cdf(next_state,
                      args$next_state,
                      extent=extent,
                      write_slice=list(crop=crop),
                      append=TRUE,
                      quick_append=TRUE)
    
    infof('Writing results for %s', crop) 
    write_vars_to_cdf(list(loss                   = wsim.lsm::coalesce(loss$next_year, loss$this_year),
                           mean_loss_current_year = growing_season_loss$this_year,
                           mean_loss_next_year    = growing_season_loss$next_year,
                           cumulative_loss_current_year = 1 - next_state$fraction_remaining_current_year,
                           cumulative_loss_next_year    = 1 - next_state$fraction_remaining_next_year),
                      args$results,
                      extent=extent,
                      write_slice=list(crop=crop),
                      append=TRUE,
                      quick_append=TRUE)
    
    if (!is.null(args$extra_output)) {
      infof('Writing extra data for %s', crop) 
      write_vars_to_cdf(list(surplus=losses$surplus$this_year,
                             deficit=losses$deficit$this_year,
                             heat=losses$heat$this_year,
                             cold=losses$cold$this_year,
                             rp_temp=rp$heat,
                             rp_surplus=rp$surplus,
                             rp_deficit=rp$deficit),
                        args$extra_output,
                        extent=extent,
                        write_slice=list(crop=crop),
                        append=TRUE,
                        quick_append=TRUE)
    }
  }
}

if (!interactive()) {
  #tryCatch(
    main(commandArgs(trailingOnly=TRUE))
   # , error=wsim.io::die_with_message)
}