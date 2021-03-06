# Copyright (c) 2018-2020 ISciences, LLC.
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
#' @param plotting_position when \code{distribution} is \code{nonparametric},
#'                          the name of the plotting position to use (e.g., 'tukey')
#' @param min.sa minimum value for clamping computed standardized anomaly
#' @param max.sa maximum value for clamping computed standardized anomaly
#'
#' @return computed standardized anomaly
#' @export
standard_anomaly <- function(distribution, dist_params, obs, plotting_position='tukey', min.sa=-100, max.sa=100) {

  if (distribution == 'nonparametric') {
    if (is.null(plotting_position)) {
      stop('Must specify a plotting position for nonparametric distribution.')
    }

    # Observations are a matrix; fit parameters are a 3D array.
    stopifnot(is.matrix(obs))
    stopifnot(all(dim(obs) == dim(dist_params)[1:2]))

    plotting_fn <- switch(plotting_position,
                          tukey = plotting_position_tukey)

    quantiles <- cdf_plotting_position(obs, dist_params, plotting_fn)
  } else {
    # parametric distribution

    quantile_fn <- switch(distribution,
                          gev= cdfgev,
                          pe3= cdfpe3,
                          NULL)

    if (is.null(quantile_fn)) {
      stop("No quantile function available for distribution \"", distribution, "\"")
    }

    if (is.array(dist_params)) {
      # Observations are a matrix; fit parameters are a 3D array.
      stopifnot(is.matrix(obs))
      stopifnot(all(dim(obs) == dim(dist_params)[1:2]))

      quantiles <- quantile_fn(obs,
                               abind::adrop(dist_params[,,1, drop=FALSE], drop=3),
                               abind::adrop(dist_params[,,2, drop=FALSE], drop=3),
                               abind::adrop(dist_params[,,3, drop=FALSE], drop=3))
    } else {
      # Observations are a vector; fit parameters are constant.
      stopifnot(length(dist_params) == 3)
      quantiles <- quantile_fn(obs, dist_params[1], dist_params[2], dist_params[3])
    }
  }

  pmin(pmax(stats::qnorm(quantiles), min.sa), max.sa)
}
