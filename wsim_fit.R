#!/usr/bin/env Rscript

# Copyright (c) 2018-2019 ISciences, LLC.
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

library(Rcpp)

wsim.io::logging_init('wsim_fit')
'
Fit statistical distributions.

Usage: wsim_fit (--distribution=<dist>) (--input=<file>)... (--output=<file>) [--cores=<num>] [--attr=<attr>]...

--distribution <dist> the statistical distribution to be fit
--input <file>        Files to read observations
--output <file>       Output netCDF file with distribution fit parameters
--cores <num>         Number of CPU cores to use [default: 1]
--attr <attr>         Optional attribute(s) to write to output netCDF file
'->usage

main <- function(raw_args) {
  args <- wsim.io::parse_args(usage, raw_args, types=list(cores="integer"))

  outfile <- args$output
  if (!wsim.io::can_write(outfile)) {
    wsim.io::die_with_message("Cannot open", outfile, "for writing.")
  }

  if (args$cores > 1) {
    c1 <- parallel::makeCluster(args$cores)
    parallel::setDefaultCluster(c1)
  }

  output_attrs <- lapply(args$attr, wsim.io::parse_attr)

  expanded_inputs <- wsim.io::expand_inputs(args$input)
  wsim.io::info('Preparing to load vars from', length(expanded_inputs), "files.")
  inputs_stacked <- wsim.io::read_vars_to_cube(expanded_inputs, attrs_to_read=c('units', 'standard_name'))

  if (length(unique(dimnames(inputs_stacked)[[3]])) > 1) {
    wsim.io::die_with_message("Can't perform fit on heterogeneous input variables ( received input variables:",
                              do.call(paste, as.list(unique(dimnames(inputs_stacked)[[3]]))), ")")
  }
  fit_param_name <- dimnames(inputs_stacked)[[3]][1]

  wsim.io::info('Read', dim(inputs_stacked)[[3]], 'inputs.')

  distribution <- tolower(args$distribution)
  extra_dims <- NULL
  prec <- NULL

  tryCatch({
    fits <- wsim.distributions::fit_cell_distributions(distribution,
                                                       inputs_stacked,
                                                       log.errors=wsim.io::error)

    if (distribution == 'nonparametric') {
      # no dimnames for nonparametric
      fits <- list(ordered_values = fits)
      extra_dims <- list(n = seq_len(dim(fits$ordered_values)[3]))
      prec <- 'single'
    }
  }, error=function(e) {
    wsim.io::die_with_message(e$message)
  })

  wsim.io::write_vars_to_cdf(fits,
                             outfile,
                             extent=attr(inputs_stacked, 'extent'),
                             ids=attr(inputs_stacked, 'ids'),
                             extra_dims=extra_dims,
                             prec=prec,
                             attrs=c(
                               list(
                                 list(var=NULL,key="distribution",val=distribution),
                                 list(var=NULL,key="variable",val=fit_param_name),
                                 list(var=NULL,key="units", val=attr(inputs_stacked, "units")),
                                 list(var=NULL,key="standard_name", val=attr(inputs_stacked, "standard_name"))
                               ),
                               output_attrs # include output_attrs after standard attrs so that we can overwrite defaults (e.g., unit change)
                             ))

  wsim.io::info('Wrote fits to', outfile)
}

tryCatch(main(commandArgs(TRUE)), error=wsim.io::die_with_message)
