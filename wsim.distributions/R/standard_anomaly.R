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

#' Compute the standardized anomaly associated with an observation
#'
#' @param distribution name of distribution used for \code{dist_params}
#' @param dist_params 3D arary of distribution parameters
#' @param obs observed value for which a standard anomaly should be computed
#' @param min.sa minimum value for clamping computed standardized anomaly
#' @param max.sa maximum value for clamping computed standardized anomaly
#'
#' @return computed standardized anomaly
#' @export
standard_anomaly <- function(distribution, dist_params, obs, min.sa=-100, max.sa=100) {

  quantile_fn <- switch(distribution,
                        gev= gev_quantiles,
                        pe3= pe3_quantiles,
                        NULL)

  if (is.null(quantile_fn)) {
    stop("No quantile function available for distribution \"", distribution, "\"")
  }

  pmin(pmax(stats::qnorm(quantile_fn(obs,
                                     abind::adrop(dist_params[,,1, drop=FALSE], drop=3),
                                     abind::adrop(dist_params[,,2, drop=FALSE], drop=3),
                                     abind::adrop(dist_params[,,3, drop=FALSE], drop=3))), min.sa), max.sa)
}
