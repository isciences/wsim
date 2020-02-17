# Copyright (c) 2020 ISciences, LLC.
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

#' Compute a comulative probablility for an observation, given an ordered list of historical observations
#'
#' @param obs observation for which a probability should be computed
#' @param ranked_historical_obs an array of historical observations, stored as sorted
#'                              values along the 3rd dimension
#' @param plotting_position_fn a function that computes a probability given a rank
#'                             and number of *historical* observations as arguments
#' @return cumulative probability for each values of \code{obs}
#' @export
cdf_plotting_position <- function(obs, ranked_historical_obs, plotting_position_fn) {
  min_ranks <- stack_min_rank(obs, ranked_historical_obs)
  max_ranks <- stack_max_rank(obs, ranked_historical_obs)
  n_obs <- stack_num_defined(ranked_historical_obs)

  min_quantile <- plotting_position_fn(min_ranks, n_obs)
  max_quantile <- plotting_position_fn(max_ranks, n_obs)

  # if min and max quantile span 0.5, consider the result to be 0.5
  # otherwise, use whichever produces the smaller anomaly
  adjusted_quantile(min_quantile, max_quantile)
}

#' Compute an adjusted quantile that handles rank ties
#'
#' Compares the minimum and maximum rank of an observation and
#' returns the quantile closest to the median.
#'
#' @param min_quantile quantile of an observation, computed by
#'                     taking rank to be the smallest among
#'                     tied observations
#' @param max_quantile quantile of an observation, computed by
#'                     taking rank to be the largest among
#'                     tied observations
#'
#' @return a quantile computed as described above
#' @export
adjusted_quantile <- function(min_quantile, max_quantile) {
  ifelse(min_quantile < 0.5 & max_quantile > 0.5,
         0.5,
         ifelse(abs(0.5 - min_quantile) < abs(0.5 - max_quantile),
                min_quantile,
                max_quantile))
}

#' Compute the Tukey plotting position
#'
#' Tukey plotting position is computed using the formulation in Wilks (2011)
#' equation 7.43.
#'
#' @param rank rank of an observation
#' @param n_obs number of observations, *excluding* the observation
#'              whose plotting position is being computed
#' @return cumulative probability
plotting_position_tukey <- function(rank, n_obs) {
  (rank - 1/3)/(n_obs + 4/3)
}
