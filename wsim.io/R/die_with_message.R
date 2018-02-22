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

#' Display a message and exit the program
#'
#' All arguments will be concatenated together.
#' Program will exit with status=1
#'
#' @param ... A list that will be concatenated into an
#'            error message
#' @export
die_with_message <- function(...) {
  args <- list(...)
  if (length(args) == 1 && inherits(args[[1]], "error")) {
    fatal(args[[1]]$message)
  } else {
    fatal(...)
  }

  if(interactive()) {
    stop("Fatal error encountered in interactive session.")
  } else {
    quit(save='no', status=1, runLast=FALSE)
  }
}
