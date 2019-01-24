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

context('Crop calendar functions')

test_that('Growing season identified correctly', {
  # spring growing season
  expect_false(is_growing_season(39,  40, 180))  
  
  expect_true( is_growing_season(40,  40, 180))  
  expect_true( is_growing_season(50,  40, 180))  
  expect_true( is_growing_season(180,  40, 180))  
  
  expect_false(is_growing_season(181, 40, 180))  
  
  # winter growing season
  expect_false(is_growing_season(299, 300, 50))  
  
  expect_true( is_growing_season(300, 300, 50))  
  expect_true( is_growing_season(330, 300, 50))  
  expect_true( is_growing_season(40,  300, 50))  
  expect_true( is_growing_season(50,  300, 50))  
  
  expect_false(is_growing_season(51,  300, 50))
  
  expect_equal(NA, is_growing_season(22, NA, 60))
  expect_equal(NA, is_growing_season(22, 20, NA))
  expect_equal(NA, is_growing_season(22, NA, NA))
})

test_that('Days from planting are calculated correctly', {
  # spring growing season
  expect_equal(NA_integer_, days_since_planting(30, 40, 180))  
  expect_equal(0, days_since_planting(40, 40, 180))  
  expect_equal(130, days_since_planting(170, 40, 180))  
  expect_equal(140, days_since_planting(180, 40, 180))  
  expect_equal(NA_integer_, days_since_planting(181, 40, 180))  
  
  # winter growing season
  expect_equal(NA_integer_, days_since_planting(299, 300, 50))  
  expect_equal(0,   days_since_planting(300, 300, 50))  
  expect_equal(60,  days_since_planting(360, 300, 50))  
  expect_equal(70,  days_since_planting(5,  300, 50))  
  expect_equal(115, days_since_planting(50, 300, 50))  
  expect_equal(NA_integer_, days_since_planting(51, 300, 50))  
  
  # NA propagation
  expect_equal(NA_integer_, days_since_planting(50, NA, NA)) 
})

test_that('Days until harvest are calculated correctly', {
  # spring growing season
  expect_equal(NA_integer_, days_until_harvest(30, 40, 180))  
  expect_equal(140, days_until_harvest(40, 40, 180))  
  expect_equal(10, days_until_harvest(170, 40, 180))  
  expect_equal(0, days_until_harvest(180, 40, 180))  
  expect_equal(NA_integer_, days_until_harvest(181, 40, 180))  
  
  # winter growing season
  expect_equal(NA_integer_, days_until_harvest(299, 300, 50))  
  expect_equal(115, days_until_harvest(300, 300, 50))  
  expect_equal(55, days_until_harvest(360, 300, 50))  
  expect_equal(45, days_until_harvest(5,  300, 50))  
  expect_equal(0, days_until_harvest(50, 300, 50))  
  expect_equal(NA_integer_, days_until_harvest(51, 300, 50))  
  
  # NA propagation
  expect_equal(NA_integer_, days_until_harvest(50, NA, NA)) 
})

test_that('Functions handle vector inputs correctly', {
  # For our typical use case, we will have a constant day of the year,
  # with pixel-specific planting and harvest dates. So we want to be
  # able to call our calendar functions with a single day of year and
  # a matrix/vector of planting and harvest dates, and get a return
  # value of the same dimensions of the planting and harvest dates.
  
  expect_equal(
    c(TRUE, FALSE, NA),
    is_growing_season(180,
                      c(170, 181,  NA),
                      c(190, 190, 190)
    )
  )
})