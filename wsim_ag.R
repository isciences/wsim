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

Usage: wsim_ag --state <file> --surplus <file>... --deficit <file>... --temperature_rp <file> --calendar <file> --loss_factors <file> --next_state <file> --results <file>

Options:
--state <file>           Previous state
--surplus <file>         Return period of one or more variables associated with surplus
--deficit <file>         Return period of one or more variables associated with deficit
--temperature_rp <file>  Surface temperature return period
--calendar <file>        Crop calendar file
--loss_factors <file>    Loss factor csv
--next_state <file>      output file
--results <file>         output file
'->usage

subcrop_names <- Reduce(
  c,
  sapply(1:nrow(mirca_crops),
         function(i)
           sapply(1:mirca_crops[i, 'mirca_subcrops'],
                  function(sc)
                    sprintf('%s_%d',
                            gsub('[\\s/]+',
                                 '_',
                                 mirca_crops[i, 'mirca_name'],
                                 perl=TRUE),
                            sc))))

stress_threshold <- 30
stresses <- c('surplus', 'deficit', 'heat', 'cold')
methods <- c('irrigated', 'rainfed')

test_args <- list(
  '--state',          '/tmp/state.nc',
  '--next_state',     '/tmp/next_state.nc',
  '--results',        '/tmp/results.nc',
  '--surplus',        '/mnt/fig/WSIM/WSIM_derived_V2/composite/composite_1mo_201809.nc::surplus',
  '--deficit',        '/mnt/fig/WSIM/WSIM_derived_V2/composite/composite_1mo_201809.nc::deficit',
  '--temperature_rp', '/mnt/fig/WSIM/WSIM_derived_V2/rp/rp_1mo_201809.nc::T_rp',
  '--calendar',       '/tmp/calendar_rainfed2.nc',
  '--loss_factors',   '/home/dbaston/dev/wsim2/wsim.agriculture/data/example_crop_factors.tab'
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
  deficit <- clamp(wsim.distributions::stack_min(deficits), -60, 60)
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

  infof('Initializing state file at %s.', args$next_state)
  write_empty_state(args$next_state,
                    dim(surplus),
                    extent,
                    subcrop_names,
                    stresses,
                    fill_zero=FALSE)

  infof('Initializing results file at %s.', args$results)
  write_empty_results(args$results,
                      dim(surplus),
                      extent,
                      subcrop_names,
                      fill_zero=FALSE)

  start_of_month <- 190
  end_of_month <- 220

  loss_factors <- read.table(args$loss_factors, header=TRUE, sep='\t')
  # TODO validate crop names in loss_factors against MIRCA2K

  for (base_crop in mirca_crops$mirca_name) {
    num_subcrops <- mirca_crops[mirca_crops$mirca_name==base_crop, ]$mirca_subcrops
    for (subcrop in 1:num_subcrops) {
      crop <- sprintf('%s_%d',
                      gsub('[\\s/]+', '_', base_crop, perl=TRUE),
                      subcrop)

      calendar <- read_vars_from_cdf(args$calendar,
                                     extra_dims=list(crop=crop
                                                     )) #method=method)) # TODO add dimension, varname asserts


      plant_date <- calendar$data$plant
      harvest_date <- calendar$data$harvest

      losses <- list()
      for (stress in stresses) {
        infof('Computing %s losses for %s', stress, crop)

        early_losses <- loss_factors[loss_factors$crop==base_crop & loss_factors$days > 0, c('days', stress)]
        late_losses  <- loss_factors[loss_factors$crop==base_crop & loss_factors$days < 0, c('days', stress)]

        months_stress <- read_vars_from_cdf(paste0(args$state, '::months_stress'),
                                            extra_dims=list(crop=crop, stress=stress))$data[[1]]

        loss <- loss_function(rp[[stress]])*is_growing_season(end_of_month, plant_date, harvest_date)
        loss <- loss * growth_stage_loss_multiplier(0.5*(start_of_month+end_of_month),
                                                    plant_date,
                                                    harvest_date,
                                                    early_losses,
                                                    late_losses)
        loss <- loss * duration_loss_multiplier(months_stress)

        losses[[stress]] <- loss
        months_stress <- (months_stress + 1) * (stress > stress_threshold)
        write_vars_to_cdf(list(months_stress=months_stress),
                          args$next_state,
                          extent=extent,
                          write_slice=list(crop=crop, stress=stress),
                          append=TRUE,
                          quick_append=TRUE)
      }

      loss <- pmin(wsim.distributions::stack_sum(abind::abind(losses, along=3)), 1.0)

      cumulative_loss <- read_vars_from_cdf(paste0(args$state, '::cumulative_loss'),
                                            extra_dims=list(crop=crop))$data[[1]]
      cumulative_loss <- cumulative_loss + loss*(end_of_month-start_of_month)

      # TODO double-check date accounting (sum of monthly)
      denom <- days_since_planting(end_of_month, plant_date, harvest_date)
      growing_season_loss <- (denom > 0) * (cumulative_loss / denom)

      write_vars_to_cdf(list(cumulative_loss=cumulative_loss),
                        args$next_state,
                        extent=extent,
                        write_slice=list(crop=crop),
                        append=TRUE,
                        quick_append=TRUE)


      write_vars_to_cdf(list(loss=loss,
                             growing_season_loss=growing_season_loss),
                        args$results,
                        extent=extent,
                        write_slice=list(crop=crop),
                        append=TRUE,
                        quick_append=TRUE)
    }
  }
}
