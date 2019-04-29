# Copyright (c) 2019 ISciences, LLC.
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

#' Run a single month of the agriculture assessment
#' 
#' @param month month of the year to simulate
#' @param plant_date vector/matrix of planting dates [day of year]
#' @param harvest_date vector/matrix of harvest_dates [day of year]
#' @param prev_state a state object, with the following fields: \itemize{
#'                   \item loss_days_current_year
#'                   \item loss_days_next_year
#'                   \item fraction_remaining_current_year
#'                   \item fraction_remaining_next_year
#'                   }
#' @param stresses a named list providing the names of stresses and the
#'                 return period of each
#' @param loss_params parameters for the loss function, as returned by 
#'                    \code{\link{read_loss_parameters}}
#' @return a list with the following fields: \itemize{
#'           \item next_state the state at the end of the month, in the same
#'                 format as \code{prev_state}
#'           \item results a list of results to be reported for the month
#'           \item losses a loss associated with each of the \code{stresses}
#'         }
#' @export
run_ag <- function(month, plant_date, harvest_date, prev_state, stresses, loss_params) {
    from <- start_of_month(month)
    to <- end_of_month(month)
    days_in_month <- to - from + 1
    
    # How many days of growth did we have this month, potentially for both this year's and 
    # next year's harvests?
    gd <- list(
      this_year= growing_days_this_year(from, to, plant_date, harvest_date),
      next_year= growing_days_next_year(from, to, plant_date, harvest_date))
    
    # sanity check growing days
    stopifnot(all(is.na(gd$this_year) | (gd$this_year >= 0 & gd$this_year <= days_in_month)))
    stopifnot(all(is.na(gd$next_year) | (gd$next_year >= 0 & gd$next_year <= days_in_month)))
    
    # Growing days should then be defined wherever calendar is defined.
    stopifnot(all(is.na(gd$this_year) == is.na(plant_date)))
    stopifnot(all(is.na(gd$next_year) == is.na(plant_date)))

    losses <- lapply(names(stresses), function(stress) {
      loss_function(wsim.lsm::coalesce(stresses[[stress]], 0),
                    loss_params$loss_initial,
                    loss_params$loss_total,
                    loss_params$loss_power)
    })
    names(losses) <- names(stresses)
    
    combfn <- switch(loss_params$loss_method,
                     max=wsim.distributions::stack_max,
                     sum=wsim.distributions::stack_sum,
                     stop('Unknown loss method'))
    
    loss <- pmin(combfn(abind::abind(losses, along=3)), 1.0) 
    
    # sanity check losses
    stopifnot(all(is.na(loss) | (loss >= 0 & loss <= 1)))
    
    next_state <- update_crop_state(prev_state, gd, days_in_month, loss,
                                    reset = (month==1),
                                    winter_growth = (harvest_date < plant_date),
                                    initial_fraction_remaining = 1.0)

    results <- ag_results(next_state, loss, from, to, gd, plant_date, harvest_date, loss_params)
    
    return(list(
      next_state= next_state,
      results= results,
      losses= losses
    ))
}