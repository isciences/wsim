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

#' Write a RasterStack to a NetCDF file
#'
#' @param stk RasterStack containing named layers
#' @param filename output filename
#' @param attrs list of attributes to attach to the file,
#'        e.g., list(
#'                list(key='distribution', val='GEV'), # global attribute
#'                list(var='precipitation', key='units', val='mm)
#'              )
#' @param prec data type for values.  Valid types:
#'       * short
#'       * integer
#'       * float
#'       * double
#'       * char
#'       * byte
#' @export
write_stack_to_cdf <- function(stk, filename, attrs=list(), prec="double") {
  minlat <- raster::extent(stk)[3]
  maxlat <- raster::extent(stk)[4]

  minlon <- raster::extent(stk)[1]
  maxlon <- raster::extent(stk)[2]

  data <- lapply(1:raster::nlayers(stk), function(i) {
    raster::as.matrix(stk[[i]])
  })
  names(data) <- names(stk)

  write_vars_to_cdf(vars=data, filename=filename, xmin=minlon, xmax=maxlon, ymin=minlat, ymax=maxlat, attrs=attrs, prec=prec)
}
