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

#' Apply a function to each pixel of (2,3)D array, passing fit parameters as reference
#'
#' @param dist a (2,3)D array of distribution fit parameters
#' @param obs a (2,3)D array of observation parameters
#' @param fn  A function to apply the distribution to the observations,
#'            when the distribution is defined.  Should have signature
#'            \code{function(values, dist_params)}. The function should return
#'            a vector of the same length for all pixels.
#' @param when.dist.undefined A value to use when the distribution is
#'                            undefined. Length must match the return
#'                            value of \code{fn}.
#' @return a (2,3)D array of values returned by \code{fn}
#'
#' @export
apply_dist_to_array <- function(dist, obs, fn, when.dist.undefined=NA) {
  stopifnot(dim(dist)[1] == dim(obs)[1])
  stopifnot(dim(dist)[2] == dim(obs)[2])

  n_dist <- dim(dist)[[3]]

  combined <- abind::abind(dist, obs, along=3)

  array_apply(combined, function(vals) {
    dist_ij <- vals[1:n_dist]

    if (any(is.na(dist_ij))) {
      return(when.dist.undefined)
    }

    obs_ij <- vals[-(1:n_dist)]

    return(fn(obs_ij, dist_ij))
  })
}
