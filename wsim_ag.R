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
  library(Rcpp)
  library(wsim.io)
  library(wsim.agriculture)
})

'
Compute crop-specific loss risk

Usage: wsim_ag --state <file> --surplus <file>... --deficit <file>... --temperature_rp <file> --loss_params <file> --calendar <file> --next_state <file> --results <file> --yearmon <yearmon> [--extra_output <file>]

Options:
--state <file>           Previous state
--surplus <file>         Return period of one or more variables associated with surplus
--deficit <file>         Return period of one or more variables associated with deficit
--extra_output <file>    Optional file to which intermediate calculations can be saved
--temperature_rp <file>  Surface temperature return period
--calendar <file>        Crop calendar file
--next_state <file>      output file
--results <file>         output file
--yearmon <yearmon>      yearmon
--loss_params <file>     File defining parameters for loss function
'->usage

stresses <- c('surplus', 'deficit', 'heat', 'cold')

test_args <- list(
  '--state',          '/home/dbaston/wsim/oct22/agriculture/state_rainfed/state_195501.nc',
  '--next_state',     '/home/dbaston/wsim/oct22/agriculture/state_rainfed/state_195502.nc',
  '--results',        '/home/dbaston/wsim/oct22/agriculture/results_rainfed/results_1mo_195501.nc',
  '--extra_output',   '/home/dbaston/wsim/oct22/agriculture/results_rainfed/extra_output_1mo_195501.nc',
  '--surplus',        '/home/dbaston/wsim/oct22/rp/rp_1mo_195501.nc::RO_mm_rp',
  '--deficit',        '/home/dbaston/wsim/oct22/rp/rp_1mo_195501.nc::PETmE_rp@negate,Ws_rp',
  '--temperature_rp', '/home/dbaston/wsim/oct22/rp/rp_1mo_195501.nc::T_rp',
  '--calendar',       '/mnt/fig_rw/WSIM_DEV/source/MIRCA2000/crop_calendar_rainfed.nc',
  '--yearmon',        '195501'
)

clamp <- function(vals, minval, maxval) {
  pmax(pmin(vals, maxval), minval)
}

main <- function(raw_args) {
  args <- wsim.io::parse_args(usage, raw_args)
  
  loss_params <- read_loss_parameters(args$loss_params)

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

  heat <- clamp(wsim.io::read_vars(args$temperature_rp,
                                   expect.nvars=1,
                                   expect.dims=dim(surplus),
                                   expect.extent=extent)$data[[1]],
                -60, 60)

  cold <- (-heat)

  rp <- list(
    surplus=surplus,
    deficit=deficit,
    heat=heat,
    cold=cold
  )

  res <- c(extent[4]-extent[3], extent[2]-extent[1]) / dim(surplus)
  
  all_in_memory <- TRUE

  if (all_in_memory) {
    states_to_write <- list(
      loss_days_current_year = list(),
      loss_days_next_year = list(),
      fraction_remaining_current_year = list(),
      fraction_remaining_next_year = list()
    )
  
    results_to_write <- list(
      loss= list(),
      mean_loss_current_year= list(),
      mean_loss_next_year= list(),
      cumulative_loss_current_year= list(),
      cumulative_loss_next_year= list()
    )
    
    extra_data_to_write <- list(
      surplus=list(),
      deficit=list(),
      heat=list(),
      cold=list(),
      rp_temp=list(),
      rp_surplus=list(),
      rp_deficit=list()
    )
  } else {
    infof('Initializing results file at %s.', args$results)
    write_empty_results(fname=args$results,
                        res=res,
                        extent=extent,
                        fill_zero=FALSE)
    
    infof('Initializing state file at %s.', args$next_state, res[1],res[2])
    write_empty_state(fname=args$next_state,
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
  }

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
    
    initial_fraction_remaining <- initial_crop_fraction_remaining(growing_season_length(plant_date, harvest_date),
                                                                  loss_params$mean_loss_fit_a,
                                                                  loss_params$mean_loss_fit_b)

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

    losses <- lapply(stresses, function(stress) {
      loss_function(wsim.lsm::coalesce(rp[[stress]], 0),
                    loss_params$loss_initial,
                    loss_params$loss_total,
                    loss_params$loss_power)
    })
    names(losses) <- stresses
    
    loss <- pmin(wsim.distributions::stack_sum(abind::abind(losses, along=3)), 1.0) 
    
    # sanity check losses
    stopifnot(all(is.na(loss) | (loss >= 0 & loss <= 1)))
    
    prev_state <- read_vars_from_cdf(sprintf('%s::%s', args$state, paste('loss_days_current_year',
                                                                         'loss_days_next_year',
                                                                         'fraction_remaining_current_year',
                                                                         'fraction_remaining_next_year',
                                                                         sep=',')),
                                     extra_dims=list(crop=crop))$data

    next_state <- update_crop_state(prev_state, gd, days_in_month, loss,
                                    reset = (month==1),
                                    winter_growth = (harvest_date < plant_date),
                                    initial_fraction_remaining = initial_fraction_remaining)
    
    # state variables are defined wherever calendars are
    stopifnot(all(is.na(plant_date) == is.na(next_state$fraction_remaining_current_year)))
    stopifnot(all(is.na(plant_date) == is.na(next_state$fraction_remaining_next_year)))
    stopifnot(all(is.na(plant_date) == is.na(next_state$loss_days_current_year)))
    stopifnot(all(is.na(plant_date) == is.na(next_state$loss_days_next_year)))

    growing_season_loss <- list(
      this_year= ifelse(days_since_planting$this_year > 0, next_state$loss_days_current_year / days_since_planting$this_year, NA),
      next_year= ifelse(days_since_planting$next_year > 0, next_state$loss_days_next_year    / days_since_planting$next_year, NA)
    )
    
    loss[((is.na(gd$this_year) | gd$this_year < 1) & (is.na(gd$next_year) | gd$next_year < 1))] <- NA
        
    if (all_in_memory) {
      for (v in names(next_state)) {
        states_to_write[[v]][[crop]] <- next_state[[v]]
      }
    } else {
      infof('Writing next state for %s', crop) 
      write_vars_to_cdf(next_state,
                        args$next_state,
                        extent=extent,
                        write_slice=list(crop=crop),
                        append=TRUE,
                        quick_append=TRUE)
    }
    
    results <- list(
      loss=                         loss,
      mean_loss_current_year=       growing_season_loss$this_year,
      mean_loss_next_year=          growing_season_loss$next_year,
      cumulative_loss_current_year= pmax(1 - next_state$fraction_remaining_current_year, 0),
      cumulative_loss_next_year=    pmax(1 - next_state$fraction_remaining_next_year, 0)
    )
    
    if (all_in_memory) {
      for (v in names(results)) {
        results_to_write[[v]][[crop]] <- results[[v]]
      }
    } else {
      infof('Writing results for %s', crop) 
      write_vars_to_cdf(results,
                        args$results,
                        extent=extent,
                        write_slice=list(crop=crop),
                        append=TRUE,
                        quick_append=TRUE)
    }
    
    if (!is.null(args$extra_output)) {
      to_write <- list(
        surplus=    losses$surplus,
        deficit=    losses$deficit,
        heat=       losses$heat,
        cold=       losses$cold,
        rp_temp=    rp$heat,
        rp_surplus= rp$surplus,
        rp_deficit= rp$deficit
      )  
      
      if (all_in_memory) {
        for (v in names(to_write)) {
          extra_data_to_write[[v]][[crop]] <- to_write[[v]]
        }
      } else {
        infof('Writing extra data for %s', crop) 
        write_vars_to_cdf(to_write,
                          args$extra_output,
                          extent=extent,
                          write_slice=list(crop=crop),
                          append=TRUE,
                          quick_append=TRUE)
      }
    }
  }
  
  if (all_in_memory) {
    infof('Writing next state to %s', args$next_state)
    write_vars_to_cdf(lapply(states_to_write, abind::abind, rev.along=0),
                      args$next_state,
                      extent=extent,
                      extra_dims=list(crop=wsim_subcrop_names()))
    infof('Writing results to %s', args$results)
    write_vars_to_cdf(lapply(results_to_write, abind::abind, rev.along=0),
                      args$results,
                      extent=extent,
                      extra_dims=list(crop=wsim_subcrop_names()))
    if (!is.null(args$extra_output)) {
      infof('Writing extra output to %s', args$extra_output)
      write_vars_to_cdf(lapply(extra_data_to_write, abind::abind, rev.along=0),
                        args$extra_output,
                        extent=extent,
                        extra_dims=list(crop=wsim_subcrop_names()))
    }
  }
                    
}

if (!interactive()) {
  tryCatch(
    main(commandArgs(trailingOnly=TRUE))
  ,error=wsim.io::die_with_message)
}

#main(test_args)