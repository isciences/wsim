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

Usage: wsim_ag --state <file> --surplus <file> --deficit <file> --temperature_rp <file> --calendar <file> --loss_factors <file> --output <file>

Options:
--state <file>           Previous state
--surplus <file>         Composite surplus index
--deficit <file>         Composite deficit index
--temperature_rp <file>  Surface temperature return period
--calendar <file>        Crop calendar file
--loss_factors <file>    Loss factor csv
--output <file>          output file
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

test_args <- list(
  '--state',          '/tmp/state.nc',
  '--output',         '/tmp/next_state.nc',
  '--surplus',        '/mnt/fig/WSIM/WSIM_derived_V2/composite/composite_1mo_201809.nc::surplus',
  '--deficit',        '/mnt/fig/WSIM/WSIM_derived_V2/composite/composite_1mo_201809.nc::deficit',
  '--temperature_rp', '/mnt/fig/WSIM/WSIM_derived_V2/rp/rp_1mo_201809.nc::T_rp',
  '--calendar',       '/tmp/calendar.nc',
  '--loss_factors',   '/home/dbaston/dev/wsim2/wsim.agriculture/data/example_crop_factors.tab'
)

main <- function(raw_args) {
  args <- wsim.io::parse_args(usage, raw_args)
  
  surplus <- wsim.io::read_vars(args$surplus)
  extent <- surplus$extent
  surplus <- surplus$data[[1]]
  
  deficit <- wsim.io::read_vars(args$deficit,
                                expect.nvars=1,
                                expect.dims=dim(surplus),
                                expect.extent=extent)$data[[1]]
  
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
  
  write_empty_state(args$output,
                    dim(surplus),
                    extent,
                    subcrop_names,
                    stresses,
                    fill_zero=FALSE)
  
    
  day_of_year <- 220
  
  loss_factors <- read.table(args$loss_factors, header=TRUE, sep='\t')
  # TODO validate crop names in loss_factors against MIRCA2K

  for (base_crop in mirca_crops$mirca_name) {
    num_subcrops <- mirca_crops[mirca_crops$mirca_name==base_crop, ]$mirca_subcrops
    for (subcrop in 1:num_subcrops) {
      crop <- sprintf('%s_%d',
                      gsub('[\\s/]+', '_', base_crop, perl=TRUE),
                      subcrop)  
      
      calendar <- read_vars_from_cdf(args$calendar,
                                     extra_dims=list(crop=crop)) # TODO add dimension, varname asserts
      plant_date <- calendar$data$plant
      harvest_date <- calendar$data$harvest
      
      losses <- list()
      for (stress in stresses) {
        infof('Computing %s losses for %s', stress, crop)
        
        early_losses <- loss_factors[loss_factors$crop==base_crop & loss_factors$days > 0, c('days', stress)]
        late_losses  <- loss_factors[loss_factors$crop==base_crop & loss_factors$days < 0, c('days', stress)]
        
        months_stress <- read_vars_from_cdf(paste0(args$state, '::months_stress'), 
                                            extra_dims=list(crop=crop, stress=stress))$data[[1]]
        
        loss <- loss_function(rp[[stress]])
        loss <- loss * growth_stage_loss_multiplier(day_of_year,
                                                    plant_date,
                                                    harvest_date,
                                                    early_losses,
                                                    late_losses)
        loss <- loss * duration_loss_multiplier(months_stress)
        
        losses[[stress]] <- loss
        months_stress <- (months_stress + 1) * (stress > stress_threshold)
        write_vars_to_cdf(list(months_stress=months_stress),
                          args$output,
                          extent=extent,
                          write_slice=list(crop=crop, stress=stress),
                          append=TRUE,
                          quick_append=TRUE)
      }
      
      # TODO avoid NA propagation when only some of losses are NA
      loss <- pmin(Reduce('+', losses), 1.0)
      
      cumulative_loss <- read_vars_from_cdf(paste0(args$state, '::cumulative_loss'),
                                            extra_dims=list(crop=crop))$data[[1]]
      cumulative_loss <- cumulative_loss + loss
      
      write_vars_to_cdf(list(cumulative_loss=cumulative_loss),
                        args$output,
                        extent=extent,
                        write_slice=list(crop=crop),
                        append=TRUE,
                        quick_append=TRUE)
    }
  }
}
