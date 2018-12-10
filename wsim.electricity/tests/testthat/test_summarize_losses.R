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

context('Loss summary')

test_that('Dry-cooled or seawater-cooled thermal plants are considered reserve', {
  expect_equal(10, calculate_reserve_capacity(fuel='Oil',
                                              water_cooled=FALSE,
                                              seawater_cooled=FALSE,
                                              capacity_mw=15,
                                              generation_mw=5))
  
  expect_equal(10, calculate_reserve_capacity(fuel='Nuclear',
                                              water_cooled=TRUE,
                                              seawater_cooled=TRUE,
                                              capacity_mw=100,
                                              generation_mw=90))
})

test_that('Non-water-cooled plants for certain fuel types are not considered reserve', {
  expect_equal(0, calculate_reserve_capacity(fuel='Solar',
                                             water_cooled=FALSE,
                                             seawater_cooled=FALSE,
                                             capacity_mw=1,
                                             generation_mw=0.1))  
  
})

test_that('Freshwater-cooled plants are not considered reserve', {
  expect_equal(0, calculate_reserve_capacity(fuel='Nuclear',
                                             water_cooled=TRUE,
                                             seawater_cooled=FALSE,
                                             capacity_mw=100,
                                             generation_mw=80))
})

test_that('Reserve capacity calculation is vectorized', {
  expect_equal(c(10, 20),
               calculate_reserve_capacity(fuel=            c('Nuclear', 'Oil'),
                                          water_cooled=    c(     TRUE, FALSE),
                                          seawater_cooled= c(     TRUE, FALSE),
                                          capacity_mw=     c(      100,   100),
                                          generation_mw=   c(      90,     80)))
})

test_that('Summary produces correct_results', {
  dat <- data.frame(
    id=             c(      1,       2,         3,     4,       5,     6,       7),
    province_id=    c(      1,       1,         1,     1,       2,     2,       3),
    fuel=           c('Hydro', 'Hydro', 'Nuclear', 'Oil', 'Hydro', 'Gas', 'Solar'),
    water_cooled=   c(  FALSE,   FALSE,      TRUE, FALSE,   FALSE,  TRUE,   FALSE),
    seawater_cooled=c(  FALSE,   FALSE,     FALSE, FALSE,   FALSE, FALSE,   FALSE),
    capacity_mw=    c(    100,      70,       300,    20,      30,    40,       5),
    generation_mw=  c(     40,      50,       220,     5,      20,    20,       2)
  )
  
  loss <- data.frame(
    id=             c(      1,       2,         3,     4,       5,     6,       7),
    loss_risk=      c(    0.5,      0.4,     0.05,    0.2,    0.4,    0.2,      0)
  )
  attr(loss$id, 'source') <- 'unknown' # provoke dplyr attribute mismatch warning
  
  expect_warning(
    # Make sure dplyr attribute mismatch warning is suppressed
    datsum <- summarize_losses(dat, loss, 'province_id')
  , regexp=NA)
  
  # TODO reserve capacity should take temperature losses into account
  expect_equal(as.list(datsum[1, ]),
               list(province_id=1,
                    capacity_tot_mw= 100+70+300+20,
                    generation_tot_mw= 40+50+220+5,
                    capacity_reserve_mw= 0+0+0+(20-5),
                    gross_loss_mw= 0.5*40 + 0.4*50 + 0.05*220 + 0.2*5,
                    net_loss_mw= (0.5*40 + 0.4*50 + 0.05*220 + 0.2*5) - (20 - 5),
                    hydro_loss_mw= 40*0.5 + 0.4*50,
                    nuclear_loss_mw= 220*0.05,
                    gross_loss_pct= (0.5*40 + 0.4*50 + 0.05*220 + 0.2*5) / (40 + 50 + 220 + 5),
                    net_loss_pct= ((0.5*40 + 0.4*50 + 0.05*220 + 0.2*5) - (20 - 5)) / (40+50+220+5),
                    hydro_loss_pct= (40*0.5 + 0.4*50)/(40 + 50),
                    nuclear_loss_pct= 220*0.05/220,
                    reserve_utilization_pct= 1
               ))
  
  expect_equal(as.list(datsum[2, ]),
                list(
                    province_id= 2,
                    capacity_tot_mw= 30+40,
                    generation_tot_mw= 20+20,
                    capacity_reserve_mw= 0+0,
                    gross_loss_mw= 20*0.4 + 20*0.2,
                    net_loss_mw= 20*0.4 + 20.*0.2 - 0,
                    hydro_loss_mw= 20*0.4,
                    nuclear_loss_mw= 0,
                    gross_loss_pct= (20*0.4 + 20*0.2)/(20 + 20),
                    net_loss_pct= (20*0.4 + 20*0.2 - 0)/(20 + 20),
                    hydro_loss_pct= 20*0.4 / 20,
                    nuclear_loss_pct= NA_real_,
                    reserve_utilization_pct= NA_real_
               ))
  
  expect_equal(as.list(datsum[3, ]),
                list(
                    province_id= 3,
                    capacity_tot_mw= 5,
                    generation_tot_mw= 2,
                    capacity_reserve_mw= 0,
                    gross_loss_mw= 2*0,
                    net_loss_mw= 2*0,
                    hydro_loss_mw= 0,
                    nuclear_loss_mw= 0,
                    gross_loss_pct= 0,
                    net_loss_pct= 0,
                    hydro_loss_pct= NA_real_,
                    nuclear_loss_pct= NA_real_,
                    reserve_utilization_pct= NA_real_
               ))
  
})