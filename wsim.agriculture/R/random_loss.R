# Copyright (c) 2019 ISciences, LLC. # All rights reserved.
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

#' Generate a value of loss for a single month
#' 
#' @param n_surplus   number of surplus variables
#' @param n_deficit   number of deficit variables
#' @param independent are variables independent (uncorrelated?) if \code{FALSE},
#'                    surplus will be assumed to have the same return period as 
#'                    heat and deficit will be assumed to have the same return
#'                    period as cold.
#' @param combine_with specifies how losses from multiple stresses should be
#'                     combined. options: [sum, max]                   
#' @param ...         arguments to pass to \code{loss_function}
#' @return returns a generated loss value from 0 to 1
#' @export
random_loss <- function(n_surplus, n_deficit, independent, combine_with, ...) {
  heat_rp <- quantile2rp(stats::runif(1))  
  cold_rp <- -heat_rp
  
  if (independent) {
    surplus_rp <- max(quantile2rp(stats::runif(n_surplus)))
    deficit_rp <- max(quantile2rp(stats::runif(n_deficit)))
  } else {
    surplus_rp <- heat_rp
    deficit_rp <- -heat_rp
  }
  
  if (combine_with == 'sum') {
    return(min(1.0,
               loss_function(heat_rp, ...) +
                 loss_function(cold_rp, ...) +
                 loss_function(surplus_rp, ...) +
                 loss_function(deficit_rp, ...)))
  } else if (combine_with == 'max') {
    return(min(1.0,
               max(loss_function(heat_rp, ...),
                   loss_function(cold_rp, ...),
                   loss_function(surplus_rp, ...),
                   loss_function(deficit_rp, ...)) 
               ))
  } else {
    stop('Unknown loss combination method: ', combine_with)  
  }
  
}

# Convert a quantile to a return period (copied from wsim.distributions
# package to avoid adding a dependency for such a small function.
quantile2rp <- function(q) {
  1/((q>0.5) - q)
}