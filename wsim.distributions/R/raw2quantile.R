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

#' Calculate the quantile of a raw forecast
#'
#' Calculate the quantile of a raw forecast relative to retrospective forecasts
#'
#' @param forecast a matrix of forecasted values
#' @param retro_fit a 3D array of GEV fit parameters from retrospective forecasts
#' @return a matrix of quantiles for each observation
raw2quantile <- function(forecast, retro_fit) {
  apply_dist_to_array(retro_fit,
                      forecast,
                      lmom::cdfgev,
                      when.dist.undefined=0.5)
}
