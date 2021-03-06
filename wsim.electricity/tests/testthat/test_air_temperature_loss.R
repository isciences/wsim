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
  plant_air_temps <- -20:-25 
  
  loss <- temperature_loss(To=plant_air_temps, To_rp=-35, Tc=-15, Tc_rp=-30)
  
  expect_increasing(loss)
  expect_equal(length(loss), length(plant_air_temps))
})

test_that('There are no cold-induced temperature losses if the cold is not unusual', {
  expect_equal(temperature_loss(To=-100, To_rp=-15, Tc=-15, Tc_rp=-30), 0)  
})

test_that('When basin water temperature is already above the regulatory limit, the plant cannot operate (100% loss)', {
  expect_equal(temperature_loss(Tbas=water2air(32) + 0.001, Treg=32, Tdiff=8), 1)  
})

test_that('If the temperature does not rise above the regulatory limit, there is no loss', {
  expect_equal(temperature_loss(Tbas=water2air(24) - 0.001, Treg=32, Tdiff=8), 0)  
  expect_equal(temperature_loss(Tbas=water2air(32) - 0.001, Treg=32, Tdiff=0), 0)  
})

test_that('If the temperature rises above the regulatory limit, production must be scaled back', {
  temps <- 24:32
  expect_increasing(temperature_loss(Tbas=temps, Treg=32, Tdiff=8))
})

test_that('At or below Teff, there is no efficiency reduction', {
  expect_equal(0, temperature_loss(To=20, Teff=20, eff=0.005))
  expect_equal(0, temperature_loss(To=19, Teff=20, eff=0.005))
})

test_that('Above Teff, operating efficiency is reduced', {
  plant_air_temps <- 21:25
  loss <- temperature_loss(To=plant_air_temps, Teff=20, eff=0.005)
  
  expect_increasing(loss)
  expect_equal(length(loss), length(plant_air_temps))
  expect(all(loss > 0))
})