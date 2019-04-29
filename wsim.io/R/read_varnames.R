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

#' Get the variables available in a given file
#'
#' @param fname filename to check
#' @return a character vector of variable names
#' @export
read_varnames <- function(fname) {
  if (endsWith(fname, '.nc')) {
    # exclude zero-dimension vars that are only used to store attributes (e.g., `crs`)
    sapply(Filter(function(v) {v$ndims > 0},
                  ncdf4::nc_open(fname)$var),
           function(v) v$name)
  } else {
    suppressWarnings(as.character(seq_len(rgdal::GDALinfo(fname)['bands'])))
  }
}
