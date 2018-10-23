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

wsim.io::logging_init('wsim_merge')

'
Merge raster datasets into a single netCDF

Usage: wsim_merge (--input=<file>)... (--output=<file>) [--attr=<attr>]...
'->usage

main <- function(raw_args) {
  args <- wsim.io::parse_args(usage, raw_args)

  inputs <- wsim.io::expand_inputs(args$input)

  attrs <- lapply(args$attr, wsim.io::parse_attr)

  combined <- list(
    attrs= list(),
    extent= NULL,
    ids= NULL,
    data= list()
  )

  for (input in inputs) {
    wsim.io::info('Processing', input)
    
    if (length(combined$data) == 0) {
      v <- wsim.io::read_vars(input)
      combined$extent <- v$extent
      combined$ids <- v$ids
    } else {
      v <- wsim.io::read_vars(input,
                              expect.extent=combined$extent,
                              expect.ids=combined$ids,
                              expect.dims=dim(combined$data[[1]]))
    }

    for (var in names(v$data)) {
      if (var %in% names(combined$data)) {
        wsim.io::die_with_message("Multiple definitions of variable ", var)
      }

      combined$data[[var]] <- v$data[[var]]
      
      # Attempt to assign any attributes that were specified with --attr
      # but did not have an assigned value
      for (i in seq_along(attrs)) {
        if (attrs[[i]]$var == var && is.null(attrs[[i]]$val)) {
          attrs[[i]]$val <- attr(v$data[[var]], attrs[[i]]$key)
        }
      }
    }
  }

  wsim.io::info('Writing to', args$output)
  wsim.io::write_vars_to_cdf(combined$data,
                             args$output,
                             extent=combined$extent,
                             ids=combined$ids,
                             attrs=attrs)
}

tryCatch(main(commandArgs(trailingOnly = TRUE)), error=wsim.io::die_with_message)
