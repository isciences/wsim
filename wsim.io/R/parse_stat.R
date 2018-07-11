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

#' Parse a statistic provided as a command-line argument
#'
#' Parses a statistic argument of the form
#' \code{stat}
#' or
#' \code{stat::var1,var2,var3}
#'
#' @param stat the argument string
#' @return a parsed \code{wsim.io.stat}
#' @export
parse_stat <- function(stat) {
  split_stat <- strsplit(stat, '::', fixed=TRUE)[[1]]

  if (length(split_stat) == 1) {
    return(make_stat(split_stat[1], as.character(c())))
  }

  vars_for_stat <- strsplit(split_stat[2], ',', fixed=TRUE)[[1]]
  return(make_stat(split_stat[1], vars_for_stat))
}

make_stat <- function(stat=NULL, vars=NULL) {
  structure(
    list(stat=stat, vars=vars),
    class='wsim.io.stat'
  )
}
