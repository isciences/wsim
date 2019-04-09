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

#' Simulate expected cumulative losses for growing seasons of 1-12 months
#' 
#' @param N number of trials in simulation
#' @param combine_with specifies how losses from multiple stresses should be
#'                     combined. options: [sum, max]                   
#' @param ... arguments to pass to \code{loss_function}
#' @return a data frame with columns \code{season_length_months},
#'         \code{method} (rainfed or irrigated), \code{inputs} (independent
#'         or identical), \code{mean_loss}, and \code{sd_loss}.
#' @export
simulate_expected_loss <- function(N=10000, combine_with, ...) {
  methods <- list(
    rainfed=list(
      vars_surplus=1,
      vars_deficit=2
    ),
    irrigated=list(
      vars_surplus=1,
      vars_deficit=1
    )
  )
  
  ret <- NULL
  loss_args <- list(...)
  
  for (method in names(methods)) {
    for (inputs in c('independent', 'identical')) {
      loss <- sapply(1:12, function(season_length) {
        random_loss_args <- c(list(methods[[method]]$vars_surplus,
                                   methods[[method]]$vars_deficit,
                                   inputs=='independent',
                                   combine_with),
                              loss_args)
        
        replicate(N, 1-prod(1-replicate(season_length, do.call(random_loss, random_loss_args))))
      })
      
      loss_df <- data.frame(
        season_length_months=1:12,
        method=method,
        inputs=inputs,
        mean_loss=apply(loss, 2, mean),
        sd_loss=apply(loss, 2, stats::sd),
        stringsAsFactors=FALSE
      )
      
      if (is.null(ret)) {
        ret <- loss_df
      } else {
        ret <- rbind(ret, loss_df)
      }
    }
  }
  
  return(ret)
}
