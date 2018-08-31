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

context('Air temperature loss')

expect_increasing <- function(x) {
  expect_true(!is.unsorted(x))
}

expect_decreasing <- function(x) {
  expect_increasing(rev(x))
}

test_that('No cold-induced loss when temperature is above cold-loss threshold', {
  expect_equal(temperature_loss(To=8, To_rp=1, Tc=-15, Tc_rp=-30), 0)
})

test_that('Cold-induced temperature loss increases with decreasing temperatures', {
  water_temps <- -20:-25 
  
  loss <- temperature_loss(To=water_temps, To_rp=-35, Tc=-15, Tc_rp=-30)
  
  expect_increasing(loss)
  expect_equal(length(loss), length(water_temps))
})

test_that('There are no cold-induced temperature losses if the cold is not unusual', {
  expect_equal(temperature_loss(To=-100, To_rp=-15, Tc=-15, Tc_rp=-30), 0)  
})

test_that('When water temperature is already above the regulatory limit, the plant cannot operate (100% loss)', {
  expect_equal(temperature_loss(To=water2air(32) + 0.001, Treg=32, Tdiff=8), 1)  
})

test_that('Above Teff, operating efficiency is reduced', {
  water_temps <- 21:25
  
  loss <- temperature_loss(To=water2air(water_temps), Teff=20, eff=0.005)
  
  expect_increasing(loss)
  expect_equal(length(loss), length(water_temps))
})