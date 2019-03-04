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
  '--state',          '/home/dbaston/wsim/oct22/agriculture/state_irrigated/state_201002.nc',
  '--next_state',     '/home/dbaston/wsim/oct22/agriculture/state_irrigated/state_201003.nc',
  '--results',        '/home/dbaston/wsim/oct22/agriculture/results_irrigated/results_1mo_201002.nc',
  #'--extra_output',   '/home/dbaston/wsim/oct22/agriculture/results_irrigated/extra_output_1mo_201002.nc',
  '--surplus',        '/home/dbaston/wsim/oct22/rp/rp_1mo_201002.nc::RO_mm_rp',
  '--deficit',        '/home/dbaston/wsim/oct22/agriculture/bt_ro_rp/bt_ro_rp_201002.nc',
  '--temperature_rp', '/home/dbaston/wsim/oct22/rp/rp_1mo_201002.nc::T_rp',
  '--calendar',       '/mnt/fig_rw/WSIM_DEV/source/MIRCA2000/crop_calendar_irrigated.nc',
  '--loss_factors',   '/tmp/factors.csv',
  '--yearmon',        '201002'
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
  # FIXME should -1 be put in command line arg?
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
  write_empty_state(fname=args$next_state,
                    res=res,
                    extent=extent,
                    stresses=stresses,
                    fill_zero=FALSE)

  infof('Initializing results file at %s.', args$results)
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
  loss_factors <- read.table(args$loss_factors, header=TRUE, sep='\t')

  month <- as.integer(substr(args$yearmon, 5, 6))
  from <- start_of_month(month)
  to <- end_of_month(month)

  for (crop in wsim_subcrop_names()) {
    base_crop <- strsplit(crop, '_')[[1]][1]

    # if (crop != 'maize_1')
    #  next

    calendar <- read_vars_from_cdf(args$calendar,
                                   extra_dims=list(crop=crop))

    plant_date <- calendar$data$plant
    harvest_date <- calendar$data$harvest

    # How many days of growth did we have this month, considering only the second growing season
    # in cases where this month spanned the end of an old growing season and the start of a
    # new one.
    gd <- growing_days_this_season(from, to, plant_date, harvest_date)

    # Growing days should then be defined wherever calendar is defined.
    stopifnot(all(is.na(gd) == is.na(plant_date)))

    losses <- list()
    for (stress in stresses) {
      infof('Computing %s losses for %s', stress, crop)

      early_losses <- loss_factors[loss_factors$crop==base_crop & loss_factors$days > 0, c('days', stress)]
      late_losses  <- loss_factors[loss_factors$crop==base_crop & loss_factors$days < 0, c('days', stress)]

      months_stress <- read_vars_from_cdf(paste0(args$state, '::months_stress'),
                                          extra_dims=list(crop=crop, stress=stress))$data[[1]]
      
      # Update consecutive months of stress. Reset the counter if we begin a new growing season.
      months_stress <- (months_stress*ifelse(plant_date >= from & plant_date <= to, 0, 1) + 1) *
        (wsim.lsm::coalesce(rp[[stress]], 0) > stress_threshold)

      loss <- loss_function(wsim.lsm::coalesce(rp[[stress]], 0))
      loss <- loss * growth_stage_loss_multiplier(0.5*(start_of_month(month)+end_of_month(month)),
                                                  plant_date,
                                                  harvest_date,
                                                  early_losses,
                                                  late_losses)
      loss <- loss * duration_loss_multiplier(months_stress)

      losses[[stress]] <- loss

      write_vars_to_cdf(list(months_stress=months_stress),
                        args$next_state,
                        extent=extent,
                        write_slice=list(crop=crop, stress=stress),
                        append=TRUE,
                        quick_append=TRUE)
    }

    loss <- pmin(wsim.distributions::stack_sum(abind::abind(losses, along=3)), 1.0)
    loss[is.na(gd) | gd < 1] <- NA # Set loss to NA wherever there was no growth

    # Loss should be defined wherever calendar is defined and we had at least one
    # growing day.
    stopifnot(all(is.na(loss) == (is.na(plant_date) | gd < 1)))
    cumulative_loss <- read_vars_from_cdf(paste0(args$state, '::cumulative_loss'),
                                          extra_dims=list(crop=crop))$data[[1]]

    # Wipe out cumulative loss where we've begun a new season (needed for crops in continuous growth)
    cumulative_loss <- cumulative_loss * ifelse(plant_date >= from & plant_date <= to, 0, 1)

    # Add this month's loss to cumulative loss
    cumulative_loss <- wsim.lsm::coalesce(cumulative_loss, 0) + loss*gd

    # Cumulative loss should then be defined wherever we had growth in the most recent season
    stopifnot(is.na(cumulative_loss) == (is.na(gd) | gd < 1))

    # Update time-weighted seasonal average
    denom <- days_since_planting_this_season(from, to, plant_date, harvest_date)
    growing_season_loss <- ifelse(!is.na(denom) & denom > 0, cumulative_loss / denom, NA)

    # Growing season loss should be defined whenever there was at least one growing day
    stopifnot(all(is.na(growing_season_loss) == (is.na(gd) | gd < 1)))

    # Necessary?
    #growing_season_loss[is.nan(growing_season_loss)] <- NA

    #growth_this_season <- !is.na(plant_date) & days_since_planting_this_season(from, to, plant_date, harvest_date) > 0

    write_vars_to_cdf(list(cumulative_loss=cumulative_loss),
                      args$next_state,
                      extent=extent,
                      write_slice=list(crop=crop),
                      append=TRUE,
                      quick_append=TRUE)

    write_vars_to_cdf(list(
      loss=loss,
      growing_season_loss=growing_season_loss),
      args$results,
      extent=extent,
      write_slice=list(crop=crop),
      append=TRUE,
      quick_append=TRUE)
    
    if (!is.null(args$extra_output)) {
      write_vars_to_cdf(c(losses,
                          list(rp_temp=rp$heat,
                               rp_surplus=rp$surplus,
                               rp_deficit=rp$deficit)),
                        args$extra_output,
                        extent=extent,
                        write_slice=list(crop=crop),
                        append=TRUE,
                        quick_append=TRUE)
    }
  }
}

if (!interactive()) {
  tryCatch(main(commandArgs(trailingOnly=TRUE)), error=wsim.io::die_with_message)
}