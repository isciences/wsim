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

wsim.io::logging_init('wsim_ag_spinup')
suppressMessages({
library(dplyr)
library(wsim.agriculture)
library(wsim.io)
})

'
Perform spin-up calculations for agriculture assessment

Usage: wsim_ag_spinup --output_dir <dir<

Options:
--output_dir <dir>       Output directory
'->usage

main <- function(raw_args) {
  args <- parse_args(usage, raw_args)
  
  rp_onset <- 12
  rp_total <- 80
  rp_power <- 2
  
  num_iterations = 10000
  
  infof("Performing expected loss simulations (N=%d)", num_iterations)
  simulation_results <- simulate_expected_loss(N=num_iterations, rp_onset, rp_total, rp_power)
  
  write_list <- function(dat, fname) {
    write.csv(data.frame(param=names(dat),
                         value=as.character(dat),
                         row.names=FALSE),
              fname)
  }
  
  for (method in unique(simulation_results$method)) {
    inputs <- simulation_results %>%
      filter(method==method) %>%
      group_by(season_length_months) %>%
      summarize(expected_loss= mean(mean_loss)) %>%
      transmute(season_length = 30.42*season_length_months,
                season_length2 = season_length*season_length,
                expected_loss)
    
    fit <- lm(expected_loss ~ season_length + season_length2 + 0, inputs)
    
    infof("Writing loss function params for method: %s", method)
    write_list(list(
      mean_loss_fit_a= fit$coefficients[1],
      mean_loss_fit_b= fit$coefficients[2],
      loss_initial= rp_onset,
      loss_total= rp_total,
      loss_power= rp_power
    ), file.path(args$output_dir, sprintf('loss_params_%s.csv', method)))
  }
}

if (!interactive()) {
  tryCatch(main(commandArgs(trailingOnly=TRUE)), error=wsim.io::die_with_message)
}
