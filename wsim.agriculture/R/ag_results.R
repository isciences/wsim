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

#' Compute monthly results from ag assessment
#' 
#' @param next_state state object representing state at the end of the iteration
#' @param loss       array containing monthly loss resulting from all stresses
#' @param from       first day-of-year in the iteration period
#' @param to         last day-of-year in the iteration period
#' @param gd         growing days during the iteration period, stored as a list with
#'                   \code{this_year} and code{next_year} items
#' @param plant_date planting date [day-of-year]
#' @param harvest_date harvest days [day-of-year]
#' @param loss_params parameters for the loss function, as returned by 
#'                    \code{\link{read_loss_parameters}}
#' @return a list of results to be reported, with the following items: \itemize{
#'  \item loss loss incurred from this iteration, for all stresses combined
#'  \item mean_loss_current_year mean loss over the growing season to-date for
#'        a crop that will ultimately be harvested this calendar year
#'  \item mean_loss_next_year mean loss over the growing season to-date for
#'        a crop that will ultimately be harvested next calendar year
#'  \item cumulative_loss_current_year a cumulative loss over the growing season to-date for
#'        a crop that will ultimately be harvested this calendar year
#'  \item cumulative_loss_next_year a cumulative loss over the growing season to-date for
#'        a crop that will ultimately be harvested next calendar year
#' }
#' 
#' @export
ag_results <- function(next_state, loss, from, to, gd, plant_date, harvest_date, loss_params) {
  stopifnot(is.list(next_state))
  stopifnot(is.numeric(loss))
  stopifnot(is.numeric(from))
  stopifnot(is.numeric(to))
  stopifnot(is.list(gd))
  stopifnot(is.numeric(plant_date))
  stopifnot(is.numeric(harvest_date))
  stopifnot(is.list(loss_params)) 
  
  days_since_planting <-
    list(this_year= days_since_planting_this_year(1, to, plant_date, harvest_date),
         next_year= days_since_planting_next_year(1, to, plant_date, harvest_date))
  
  initial_fraction_remaining <- list(
    this_year= initial_crop_fraction_remaining(days_since_planting$this_year, loss_params$mean_loss_fit_a, loss_params$mean_loss_fit_b),
    next_year= initial_crop_fraction_remaining(days_since_planting$next_year, loss_params$mean_loss_fit_a, loss_params$mean_loss_fit_b)
  )
  
  min_loss <- -1

  list(
    loss=                         ifelse(((is.na(gd$this_year) | gd$this_year < 1) & (is.na(gd$next_year) | gd$next_year < 1)), NA, loss),
    mean_loss_current_year=       ifelse(days_since_planting$this_year > 0, next_state$loss_days_current_year / days_since_planting$this_year, 0),
    mean_loss_next_year=          ifelse(days_since_planting$next_year > 0, next_state$loss_days_next_year    / days_since_planting$next_year, 0),
    cumulative_loss_current_year= pmax(1 - initial_fraction_remaining$this_year*next_state$fraction_remaining_current_year, min_loss),
    cumulative_loss_next_year=    pmax(1 - initial_fraction_remaining$next_year*next_state$fraction_remaining_next_year, min_loss)
  )
}