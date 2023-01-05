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

#' Parse command-line arguments from a docopt string
#'
#' If specified arguments are not valid, this function will
#' print the usage information and exit the program with
#' status=1.
#'
#' @param usage a docopt string describing program usage
#' @param args a list of command-line arguments
#' @param types an optional list of types to which specific
#'              arguments should be coerced, e.g. \code{list(num_cores="integer")}
#' @return a list of parsed arguments
#'
#' @export
parse_args <- function(usage, args=commandArgs(TRUE), types=list()) {
  parsed <- tryCatch(docopt::docopt(usage, args), error=function(e) {
    if (!interactive()) {
      write(usage, stdout())
    }

    stop('Error parsing args.')
  })

  for (arg in names(parsed)) {
    if (!is.null(parsed[[arg]])) {
      typ <- types[[arg]]
      if (!is.null(typ)) {
        cast_fn <- switch(typ,
          integer=as.integer,
          double=as.double,
          numeric=as.numeric,
          logical=as.logical
        )

        if (typ == 'integer') {
          # make sure that we throw an error if a non-integer is
          # passed to an arg expecting an integer
          if(as.integer(parsed[[arg]]) != as.numeric(parsed[[arg]])) {
            stop(sprintf('Argument %s expected an integer value but received %s', arg, parsed[[arg]]))
          }
        }

        parsed[[arg]] <- cast_fn(parsed[[arg]])
      }
    }
  }

  return(parsed)
}
