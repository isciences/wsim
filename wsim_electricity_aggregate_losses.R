#!/usr/bin/env Rscript

# Copyright (c) 2018 ISciences, LLC.
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

wsim.io::logging_init('wsim_electricity_aggregate_losses')

'
Aggregate plant-level losses to boundaries

Usage: wsim_electricity_aggregate_losses --plants=<file> --plant_losses=<file> --basis=<basis> --yearmon=<yearmon> --output=<file>

Options:
--plants <file>            Table of power plants
--plant_losses <file>      Table of predicted losses for each plant
--basis <basis>            Basis on which to aggregate losses (basin, province, country)
--yearmon <yearmon>        Year and month of predicted losess (YYYYMM)
--output <file>            Output netCDF with aggregated loss data
'->usage

main <- function(raw_args) {
  args <- wsim.io::parse_args(usage, raw_args)

  plants <- wsim.io::read_vars(args$plants, as.data.frame=TRUE)
  losses <- wsim.io::read_vars(args$plant_losses, as.data.frame=TRUE, expect.ids=plants$id)
  
  id_field <- sprintf('%s_id', args$basis)
  
  aggregated <- wsim.electricity::summarize_losses(plants, losses, id_field, 24*wsim.lsm::days_in_yyyymm(args$yearmon))
  
  wsim.io::write_vars_to_cdf(aggregated[, -1],
                             args$output,
                             ids=aggregated[[id_field]])

  wsim.io::info('Wrote aggregated losses to', args$output)
}

tryCatch(main(commandArgs(TRUE)), error=wsim.io::die_with_message)
