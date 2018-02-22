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

#' Read multiple variables from a NetCDF file to a RasterBrick
#'
#' Global attributes will be attached to the RasterBrick as
#' metadata.  Variable attributes are currently ignored.
#'
#' @param fname name of NetCDF file
#' @return RasterBrick
#' @export
read_brick_from_cdf <- function(fname) {
  cdf <- read_vars_from_cdf(fname)

  fits <- raster::brick(lapply(names(cdf$data), function(var) {
    raster::raster(cdf$data[[var]],
                   xmn=cdf$extent[1],
                   xmx=cdf$extent[2],
                   ymn=cdf$extent[3],
                   ymx=cdf$extent[4])
  }))

  names(fits) <- names(cdf$data)
  raster::metadata(fits) <- cdf$attrs

  return(fits)
}
