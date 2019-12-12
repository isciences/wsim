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

library(wsim.io)
logging_init('extract_nmme_forecast')

'
Extract a NMME forecast from NOAA "realtime" anomaly files

Usage: extract_nmme_forecast.R --clim_precip=<file> --clim_temp=<file> --anom_precip=<fille> --anom_temp=<file> --lead=<n> --member=<n> --output=<file>

Options:
--clim_precip <file>  netCDF file with precipitation climatology
--anom_precip <file>  netCDF file of precipitation anomlay forecasts
--clim_temp <file>    netCDF file with temperature climatology
--anom_temp <file>    netCDF file of temperature anomaly forecasts
--lead <n>            number of lead months
--member <r>          forecast ensemble member number
--output <attr>       output netCDF file
'->usage

main <- function(raw_args) {
  args <- parse_args(usage, raw_args, types=list(lead='integer', member='integer'))

  info('Reading precipitation forecast')
  precip_anom <- read_nmme_noaa(args$anom_precip, 'fcst', args$lead, args$member)
  precip_clim <- read_nmme_noaa(args$clim_precip, 'clim', args$lead)

  info('Reading temperature forecast')
  temp_anom <- read_nmme_noaa(args$anom_temp, 'fcst', args$lead, args$member)
  temp_clim <- read_nmme_noaa(args$clim_temp, 'clim', args$lead)

  infof('Writing outputs to %s', args$output)
  write_vars_to_cdf(list(Pr = precip_clim$data[[1]]/86400 + precip_anom$data[[1]], # climatology in mm/day, anom in mm/s
                         T =  temp_clim$data[[1]] + temp_anom$data[[1]]),
                    args$output,
                    extent=precip_clim$extent,
                    attrs=list(
                      list(var="Pr", key="units", val="kg/m^2/s"),
                      list(var="Pr", key="standard_name", val="precipitation_flux"),
                      list(var="T", key="units", val="K"),
                      list(var="T", key="standard_name", val="surface_temperature")
                    ))
}

tryCatch(main(commandArgs(trailingOnly=TRUE)), error=wsim.io::die_with_message)



