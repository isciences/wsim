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

#' Compute a matrix of monthly average day length
#'
#' @param year  year for computation. Must be >= 1900
#' @param month month for computation
#' @param extent vector of \code{(xmin, xmax, ymin, ymax)}
#' @param nrows number of rows (latitudes) in generated matrix
#' @param ncols number of columns (longitudes) in generated matrix
#'
#' @return a matrix of specified dimensions, where each cell represents
#'         the day length as a fraction of 24 hours
#' @useDynLib wsim.lsm, .registration=TRUE
#' @export
day_length_matrix <- function(year, month, extent, nrows, ncols) {
  if (year < 1900) {
    wsim.io::warn("Attempted to calculate pre-1900 day lengths ( year =", year, "). Using year = 1900 instead.")
    year <- 1900
  }

  dlat <- (extent[4] - extent[3]) / nrows
  lats <- seq(from=extent[4] - dlat/2, to=extent[3] + dlat/2, by=-dlat)
  matrix(average_day_length(lats, year, month)/24, nrow=nrows, ncol=ncols)
}
