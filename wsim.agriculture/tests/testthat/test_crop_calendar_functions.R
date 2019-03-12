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

test_that('Growing days are calculated correctly', {
  expect_equal(0,
               growing_days(5, 10, 
                            11, 15))
  
  expect_equal(2,
               growing_days(5,  12,
                            11, 15))
  
  expect_equal(3,
               growing_days(13, 15,
                            11, 15))
  
  # wrap around the calendar
  expect_equal(5,
               growing_days(10, 5,
                            11, 15))
  
  expect_equal(NA_integer_,
               growing_days(5, 10,
                            NA, NA))
})

test_that('Functions handle vector inputs correctly', {
  # For our typical use case, we will have a constant day of the year,
  # with pixel-specific planting and harvest dates. So we want to be
  # able to call our calendar functions with a single day of year and
  # a matrix/vector of planting and harvest dates, and get a return
  # value of the same dimensions of the planting and harvest dates.
  
  expect_equal(
    rbind(c(TRUE, FALSE),
          c(NA,    TRUE)),
    is_growing_season(180,
                      rbind(c(170, 181),
                            c(NA,  170)),
                      rbind(c(190, 190),
                            c(190, 190))
    )
  )
  
  expect_equal(
    rbind(c(11,             5),
          c(NA_integer_,  11)),
    growing_days(175, 185,
                 rbind(c(170, 181),
                       c(NA,  170)),
                 rbind(c(190, 190),
                       c(190, 190))
    )
  )
  
  expect_equal(
    rbind(c(10, NA_integer_),
          c(10, NA_integer_)),
    days_since_planting(180,
                      rbind(c(170, 181),
                            c(170,  NA)),
                      rbind(c(190, 190),
                            c(190,  NA))
    )
  )
  
  expect_equal(
    rbind(c(10, NA_integer_),
          c(NA_integer_, 10)),
    days_until_harvest(180,
                     rbind(c(170, 181),
                           c(NA, 170)),
                     rbind(c(190, 190),
                           c(190, 190))
    )
  )
})

test_that('growing days this season calculated correctly', {
  # ---------xxxxxxxxxx----------
  # ----P*******************H----
  cal <- list(from=10, to=19, plant_date=5, harvest_date=25) 
  
  expect_equal(10, do.call(growing_days_this_season, cal))
  expect_equal(10, do.call(growing_days_this_year, cal))
  expect_equal(0,  do.call(growing_days_next_year, cal))
  expect_equal(15, do.call(days_since_planting_this_season, cal))
  expect_equal(15, do.call(days_since_planting_this_year, cal))
  expect_equal(0,  do.call(days_since_planting_next_year, cal))
  
  # ---------xxxxxxxxxx----------
  # ---------------P********H----
  cal <- list(from=10, to=19, plant_date=16, harvest_date=25) 
  
  expect_equal(4, do.call(growing_days_this_season, cal))
  expect_equal(4, do.call(growing_days_this_year, cal))
  expect_equal(0, do.call(growing_days_next_year, cal))
  expect_equal(4, do.call(days_since_planting_this_season, cal))
  expect_equal(4, do.call(days_since_planting_this_year, cal))
  expect_equal(0, do.call(days_since_planting_next_year, cal))
  
  # ---------xxxxxxxxxx----------
  # ----P*********H--------------
  cal <- list(from=10, to=19, plant_date=5, harvest_date=15)
  
  expect_equal(6,  do.call(growing_days_this_season, cal))
  expect_equal(6,  do.call(growing_days_this_year, cal))
  expect_equal(0,  do.call(growing_days_next_year, cal))
  expect_equal(11, do.call(days_since_planting_this_season, cal))
  expect_equal(11, do.call(days_since_planting_this_year, cal))
  expect_equal(0,  do.call(days_since_planting_next_year, cal))
  
  # ---------xxxxxxxxxx----------
  # ----P****H-------------------
  cal <- list(from=10, to=19, plant_date=5, harvest_date=10) 
  
  expect_equal(1, do.call(growing_days_this_season, cal))
  expect_equal(1, do.call(growing_days_this_year, cal))
  expect_equal(0, do.call(growing_days_next_year, cal))
  expect_equal(6, do.call(days_since_planting_this_season, cal))
  expect_equal(6, do.call(days_since_planting_this_year, cal))
  expect_equal(0, do.call(days_since_planting_next_year, cal))
  
  # ---------xxxxxxxxxx----------
  # ------------------P****H-----
  cal <- list(from=10, to=19, plant_date=19, harvest_date=24) 
  
  expect_equal(1, do.call(growing_days_this_season, cal))
  expect_equal(1, do.call(growing_days_this_year, cal))
  expect_equal(0, do.call(growing_days_next_year, cal))
  expect_equal(1, do.call(days_since_planting_this_season, cal))
  expect_equal(1, do.call(days_since_planting_this_year, cal))
  expect_equal(0, do.call(days_since_planting_next_year, cal))
  
  # ---------xxxxxxxxxx----------
  # ----P*************H----------
  cal <- list(from=10, to=19, plant_date=5, harvest_date=19) 
  
  expect_equal(10, do.call(growing_days_this_season, cal))
  expect_equal(10, do.call(growing_days_this_year, cal))
  expect_equal(0,  do.call(growing_days_next_year, cal))
  expect_equal(15, do.call(days_since_planting_this_season, cal))
  expect_equal(15, do.call(days_since_planting_this_year, cal))
  expect_equal(0,  do.call(days_since_planting_next_year, cal))
  
  # ---------xxxxxxxxxx----------
  # ****H----------P*************
  cal <- list(from=10, to=19, plant_date=16, harvest_date=5) 
  
  expect_equal(4, do.call(growing_days_this_season, cal))
  expect_equal(0, do.call(growing_days_this_year, cal))
  expect_equal(4, do.call(growing_days_next_year, cal))
  expect_equal(4, do.call(days_since_planting_this_season, cal))
  expect_equal(0, do.call(days_since_planting_this_year, cal))
  expect_equal(4, do.call(days_since_planting_next_year, cal))
  
  # ---------xxxxxxxxxx----------
  # ****H-------------------P****
  cal <- list(from=10, to=19, plant_date=25, harvest_date=5) 
  
  expect_equal(0, do.call(growing_days_this_season, cal))
  expect_equal(0, do.call(growing_days_this_year, cal))
  expect_equal(0, do.call(growing_days_next_year, cal))
  expect_equal(0, do.call(days_since_planting_this_season, cal))
  expect_equal(0, do.call(days_since_planting_this_year, cal))
  expect_equal(0, do.call(days_since_planting_next_year, cal))
  
  # ---------xxxxxxxxxx----------
  # **************HP*************
  cal <- list(from=10, to=19, plant_date=16, harvest_date=15) 
  
  expect_equal(4,   do.call(growing_days_this_season, cal))
  expect_equal(6,   do.call(growing_days_this_year, cal))
  expect_equal(4,   do.call(growing_days_next_year, cal))
  expect_equal(4,   do.call(days_since_planting_this_season, cal))
  expect_equal(365, do.call(days_since_planting_this_year, cal))
  expect_equal(4,   do.call(days_since_planting_next_year, cal))
  
  # ---------xxxxxxxxxx----------
  # *************H--P************
  cal <- list(from=10, to=19, plant_date=17, harvest_date=14) 
  
  expect_equal(3,   do.call(growing_days_this_season, cal))
  expect_equal(5,   do.call(growing_days_this_year, cal))
  expect_equal(3,   do.call(growing_days_next_year, cal))
  expect_equal(3,   do.call(days_since_planting_this_season, cal))
  expect_equal(363, do.call(days_since_planting_this_year, cal))
  expect_equal(3,   do.call(days_since_planting_next_year, cal))
  
  # ---------xxxxxxxxxx----------
  # *********************H--P****
  cal <- list(from=10, to=19, plant_date=25, harvest_date=22)
  
  expect_equal(10,  do.call(growing_days_this_season, cal))
  expect_equal(10,  do.call(growing_days_this_year, cal))
  expect_equal(0,   do.call(growing_days_next_year, cal))
  expect_equal(360, do.call(days_since_planting_this_season, cal))
  expect_equal(360, do.call(days_since_planting_this_year, cal))
  expect_equal(0,   do.call(days_since_planting_next_year, cal))
  
  # ---------xxxxxxxxxx----------
  # -P**H------------------------
  cal <- list(from=10, to=19, plant_date=2, harvest_date=5) 
  
  expect_equal(0, do.call(growing_days_this_season, cal))
  expect_equal(0, do.call(growing_days_this_year, cal))
  expect_equal(0, do.call(growing_days_next_year, cal))
  expect_equal(0, do.call(days_since_planting_this_season, cal))
  expect_equal(0, do.call(days_since_planting_this_year, cal))
  expect_equal(0, do.call(days_since_planting_next_year, cal))
  
  # ---------xxxxxxxxxx----------
  # -------------------P**H------
  cal <- list(from=10, to=19, plant_date=20, harvest_date=23) 
  
  expect_equal(0, do.call(growing_days_this_season, cal))
  expect_equal(0, do.call(growing_days_this_year, cal))
  expect_equal(0, do.call(growing_days_next_year, cal))
  expect_equal(0, do.call(days_since_planting_this_season, cal))
  expect_equal(0, do.call(days_since_planting_this_year, cal))
  expect_equal(0, do.call(days_since_planting_next_year, cal))
  
  # ---------xxxxxxxxxx----------
  # -----------------------------
  cal <- list(from=10, to=19, plant_date=NA, harvest_date=NA) 
  
  expect_equal(NA_integer_, do.call(growing_days_this_season, cal))
  expect_equal(NA_integer_, do.call(growing_days_this_year, cal))
  expect_equal(NA_integer_, do.call(growing_days_next_year, cal))
  expect_equal(NA_integer_, do.call(days_since_planting_this_season, cal))
  expect_equal(NA_integer_, do.call(days_since_planting_this_year, cal))
  expect_equal(NA_integer_, do.call(days_since_planting_next_year, cal))
})
