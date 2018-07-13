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

wsim.io::logging_init('wsim_flow')

suppressMessages({
  require(Rcpp)
  require(wsim.lsm)
  require(wsim.io)
})

'
Perform pixel-based flow accumulation

Usage: wsim_flow --input=<file> --flowdir=<file> --varname=<varname> --output=<file> [--wrapx --wrapy]

Options:
--input <file>      file containing values to accumulate (e.g., runoff)
--flowdir <file>    file containing flow direction values.
                    When input is a gridded dataset, flowdir should be a grid of the same
                    extent and resolution, using D8 conventions.
                    When input is a feature dataset, flowdir should be a list of downstream
                    feature IDs.
--varname <varname> output variable name for accumulated values
--output <file>     file to which accumulated values will be written/appended
--wrapx             wrap flow in the x-dimension
--wrapy             wrap flow in the y-dimension
--invert            send flow upstream instead of downstream
'->usage

main <- function(raw_args) {
  args <- parse_args(usage, raw_args)

  if (!is.null(args$output) && !can_write(args$output)) {
    die_with_message("Cannot open ", args$output, "for writing.")
  }

  inputs <- wsim.io::read_vars(args$input, expect.nvars=1)
  wsim.io::info("Read input values.")

  flowdir <- wsim.io::read_vars(args$flowdir,
                                expect.nvars=1,
                                expect.dims=dim(inputs$data[[1]]),
                                expect.extent=inputs$extent,
                                expect.ids=inputs$ids)
  wsim.io::info("Read flow directions.")

  results <- list()
  results[[args$varname]] <- wsim.lsm::accumulate_flow(flowdir$data[[1]],
                                                       inputs$data[[1]],
                                                       args$wrapx,
                                                       args$wrapy)

  info('Flow accumulation complete')

  wsim.io::write_vars_to_cdf(
    vars= results,
    filename= args$output,
    extent= inputs$extent,
    append= TRUE
  )

  info('Wrote results to', args$output)
}

tryCatch(main(commandArgs(trailingOnly=TRUE)), error=wsim.io::die_with_message)
