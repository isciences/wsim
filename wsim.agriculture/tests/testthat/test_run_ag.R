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

context('Simulation core')

loss_params <- list(
  mean_loss_fit_a=2e-3,
  mean_loss_fit_b=-2e-6,
  loss_initial=12,
  loss_total=80,
  loss_power=2,
  loss_method='sum'
)

make_stresses <- function(seed) {
  set.seed(seed)
  stresses <- data.frame(
    month=1:12,
    heat=pmax(pmin(quantile2rp(runif(12)), 60), -60),
    surplus=pmax(pmin(quantile2rp(runif(12)), 60), -60),
    deficit=pmax(pmin(quantile2rp(runif(12)), 60), -60)
  )
  stresses$cold <- (-stresses$heat)
  
  return(stresses)
}

simulate <- function(stresses, plant_date, harvest_date) {
  prev_state <- lapply(list(
    loss_days_current_year = 0,
    loss_days_next_year = 0,
    fraction_remaining_current_year = 1.0,
    fraction_remaining_next_year = 1.0
  ), matrix)
  
  post_state <- NULL
  results <- NULL
  
  for (year in 2001:2002) {
    for (month in 1:12) {
      out <- run_ag(month, plant_date, harvest_date, prev_state, lapply(stresses[month, -1], matrix), loss_params)  
      prev_state <- out$next_state
      
      if (year > 2001) {
        post_state <- rbind(post_state, do.call(data.frame, c(list(year=year, month=month), out$next_state)))
        results <- rbind(results, do.call(data.frame, c(list(year=year, month=month), out$results)))
      }
    } 
  }
  
  return(list(
    post_state= post_state,
    results= results
  ))
}

test_that('Results are expected over summer growing season', {
  plant_date <- matrix(as.integer(strftime(as.Date('2018-04-10'), '%j')))
  harvest_date <- matrix(as.integer(strftime(as.Date('2018-10-20'), '%j')))
  stresses <- make_stresses(1001)
  
  sim <- simulate(stresses, plant_date, harvest_date)
  
  results <- sim$results
  post_state <- sim$post_state
  
  # with summer growth, we never have loss that targets the next year
  with(results,
    expect_true(all(mean_loss_next_year == 0)))
  with(results,
    expect_true(all(cumulative_loss_next_year == 0)))
  with(post_state,
       expect_true(all(loss_days_next_year == 0)))
  with(post_state,
       expect_true(all(fraction_remaining_next_year == 1)))
  
  # loss is always defined during the growing season and undefined outside of it
  with(results,
    expect_true(all(xor(month > 3 & month < 11, is.na(loss)))))
  
  # cumulative and mean loss are always defined
  with(results,
       expect_false(any(is.na(cumulative_loss_current_year))))
  with(results,
       expect_false(any(is.na(cumulative_loss_next_year))))
  with(results,
       expect_false(any(is.na(mean_loss_current_year))))
  with(results,
       expect_false(any(is.na(mean_loss_next_year))))
  
  # state variables are always defiend
  for (n in names(post_state)) {
    with(post_state,
      expect_false(any(is.na(n))))
  }
  
  # cumulative and mean loss are zero before growth starts
  expect_true(all(subset(results, month <= 3)$cumulative_loss_current_year == 0))
  expect_true(all(subset(results, month <= 3)$mean_loss_current_year == 0))
  expect_true(all(subset(post_state, month <= 3)$loss_days_current_year == 0))
  
  # similarly, fraction remaning is untouched before growth states
  expect_true(all(subset(results, month <= 3)$fraction_remaining_current_year == 1))
  
  # cumulative and mean loss are frozen in time after growth ends
  expect_true(all(subset(results, month > 10)$mean_loss_current_year == subset(results, month == 10)$mean_loss_current_year))
  expect_true(all(subset(results, month > 10)$cumulative_loss_current_year == subset(results, month == 10)$cumulative_loss_current_year))
})

test_that('Results are expected over winter growing season', {
  plant_date <- matrix(as.integer(strftime(as.Date('2018-10-20'), '%j')))
  harvest_date <- matrix(as.integer(strftime(as.Date('2018-04-10'), '%j')))
  stresses <- make_stresses(9)
  
  sim <- simulate(stresses, plant_date, harvest_date)
  
  results <- sim$results
  post_state <- sim$post_state
  
  # loss is always defined during the growing season and undefined outside of it
  with(results,
    expect_true(all(xor(month <= 4 | month >= 10, is.na(loss)))))
  
  # state variables are always defiend
  for (n in names(post_state)) {
    with(post_state,
      expect_false(any(is.na(n))))
  }
  
  # cumulative and mean loss are always defined
  with(results,
       expect_false(any(is.na(cumulative_loss_current_year))))
  with(results,
       expect_false(any(is.na(cumulative_loss_next_year))))
  with(results,
       expect_false(any(is.na(mean_loss_current_year))))
  with(results,
       expect_false(any(is.na(mean_loss_next_year))))
  
  # cumulative and mean loss are zero before growth starts
  expect_true(all(subset(results, month < 10)$cumulative_loss_next_year == 0))
  expect_true(all(subset(results, month < 10)$mean_loss_next_year == 0))
  
  # cumulative and mean loss are frozen in time after growth ends
  expect_true(all(subset(results, month > 4)$mean_loss_current_year == subset(results, month == 4)$mean_loss_current_year))
  expect_true(all(subset(results, month > 4)$cumulative_loss_current_year == subset(results, month == 4)$cumulative_loss_current_year))
  
  # spot-check
  f0 <- initial_crop_fraction_remaining(days_since_planting_this_year(start_of_month(2), end_of_month(2), plant_date, harvest_date),
                                        loss_params$mean_loss_fit_a,
                                        loss_params$mean_loss_fit_b)
  end_of_feb_loss <- (1 - f0*subset(post_state, month==2)$fraction_remaining_current_year)[1]
  expect_equal(end_of_feb_loss, subset(results, month==2)$cumulative_loss_current_year)
})