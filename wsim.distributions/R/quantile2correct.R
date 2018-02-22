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

#' quantile2correct
#'
#' Given the quantile of a forecast and a distribution of observations,
#' produce a corrected forecast by identifying the observed value whose
#' quantile corresponds to the quantile of the forecast.
#'
#' @param quant matrix with quantiles of the forecast to correct
#' @param obs_fit 3D array with parameters for the observed value distribution
#' @return matrix with a corrected forecast
quantile2correct <- function(quant, obs_fit) {
  apply_dist_to_array(obs_fit, quant, function(value, dist_params) {
    if (is.na(value)) {
      return(NA)
    }

    # TODO remove hardcoded index.  Use dist.params$location ?
    if (is.na(dist_params[1])) {
      return(NA)
    }

    # If we lack a complete CDF, return the median.
    if (is.na(dist_params[2])) {
      return(dist_params[1])
    }

    # Use CDF to match quantiles
    return (lmom::quagev(value, dist_params))
  })
}
