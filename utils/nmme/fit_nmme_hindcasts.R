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

suppressMessages({
  library(wsim.io)
  library(wsim.distributions)
})
logging_init('fit_nmme_hindcasts')

'
Fit statistical distributions from NMME hindcast files distributed by IRIDL

Usage: fit_nmme_hindcasts.R --distribution=<dist> --input=<file> --output=<file> --varname=<x> --min_year=<y> --max_year=<y> --target_month=<m> --lead=<n> [--attr=<attr>]...

--distribution <dist> the statistical distribution to be fit
--input <file>        Hindcast file from IRIDL
--varname <x>         Variable to read ("Pr" or "T")
--min_year <y>        Minimum year
--max_year <y>        Maximum year
--target_month <n>    Month targeted by forecast
--lead <n>            Number of lead months
--output <file>       Output netCDF file with distribution fit parameters
'->usage

iri_vars <- list(
  Pr = 'prec',
  T = 'tref'
)

iri_conversion_factors <- list(
  Pr = (1/86400), # mm/day to mm/s
  T = 1
)

main <- function(raw_args) {
  args <- wsim.io::parse_args(usage, raw_args, types=list(target_month='integer',
                                                          lead='integer',
                                                          max_year='integer',
                                                          min_year='integer'))
  stopifnot(args$varname %in% c('Pr', 'T'))

  outfile <- args$output
  if (!wsim.io::can_write(outfile)) {
    wsim.io::die_with_message("Cannot open", outfile, "for writing.")
  }

  dat <- read_iri_hindcast(fname = args$input,
                           var = iri_vars[[args$varname]],
                           target_month = args$target_month,
                           lead_months = args$lead,
                           min_target_year = args$min_year,
                           max_target_year = args$max_year,
                           progress = TRUE) * iri_conversion_factors[[args$varname]]

  wsim.io::infof("Read %d hindcasts for month %d (lead %d) from %s",
                 dim(dat)[3], args$target_month, args$lead, args$input)

  fits <- nmme_to_halfdeg(fit_cell_distributions(args$distribution, dat))

  wsim.io::infof("Completed %s distribution fit.", args$distribution)

  wsim.io::write_vars_to_cdf(fits,
                             outfile,
                             extent = c(-180, 180, -90, 90),
                             attrs = c(
                               list(
                                 list(var = NULL, key = "month", val = args$target_month),
                                 list(var = NULL, key = "lead_months", val = args$lead),
                                 list(var = NULL, key = "fit_years", val = sprintf("%d-%d", args$min_year, args$max_year)),
                                 list(var = NULL, key = "distribution", val = args$distribution),
                                 list(var = NULL, key = "variable", val = args$varname)
                             )))

  wsim.io::infof("Wrote distribution fits to %s.", outfile)
}

#tryCatch(
  main(commandArgs(trailingOnly=TRUE))
#,error=wsim.io::die_with_message)
