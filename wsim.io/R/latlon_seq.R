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

#' Compute a sequence of latitude values (N to S)
#'
#' @param extent of the form \code{xmin, xmax, ymin, ymax}
#' @param dims   matrix dimensions
#' @return sequence of latitudes
lat_seq <- function(extent, dims) {
  minlat <- extent[3]
  maxlat <- extent[4]

  nlat <- dims[1]
  dlat <- (maxlat - minlat) / nlat

  as.double(seq(maxlat - (dlat/2), minlat + (dlat/2), by=-dlat))
}

#' Compute a sequence of longitude values (W to E)
#'
#' @param extent of the form \code{xmin, xmax, ymin, ymax}
#' @param dims   matrix dimensions
#' @return sequence of longitudes
lon_seq <- function(extent, dims) {
  minlon <- extent[1]
  maxlon <- extent[2]

  nlon <- dims[2]

  dlon <- (maxlon - minlon) / nlon
  as.double(seq(minlon + (dlon/2), maxlon - (dlon/2), by=dlon))
}
