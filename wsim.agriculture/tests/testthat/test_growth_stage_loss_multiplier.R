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

context('Growth stage loss multiplier')

test_that('Growth stage losses calculated correctly', {
  early_losses <-rbind(
    # + ---------- + ---------- +
    # | Days since |    Loss    |
    # | planting   | Multiplier |
    # + ---------- + ---------- +
    c(           0,         1.25),
    c(          30,            1)
  )
  
  late_losses <- rbind(
    # + ---------- + ---------- +
    # | Days until |    Loss    |
    # | harvest    | Multiplier |
    # + ---------- + ---------- +
    c(          120,           1),
    c(           90,         1.5),
    c(           30,        1.25),
    c(            0,           1)
  )
  
  # non-overlapping loss ranges
  plant_day <- 120
  harvest_day <- 280
  
  loss_for_day <- function(day) {
    growth_stage_loss_multiplier(day, plant_day, harvest_day, early_losses, late_losses)
  }
  
  expect_equal(1.25, loss_for_day(120))
  expect_equal(1,    loss_for_day(120 + 30))
  
  expect_equal(1,    loss_for_day(280 - 120))
  expect_equal(1.5,  loss_for_day(280 - 90))
  expect_equal(1.25, loss_for_day(280 - 30))
  expect_equal(1,    loss_for_day(280))
})
