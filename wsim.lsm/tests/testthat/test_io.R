# Copyright (c) 2018-2021 ISciences, LLC.
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

require(testthat)

context('LSM IO functions')

test_that('we can read and write states from/to netCDF', {
  fname <- tempfile()

  state <- make_state(
    extent=c(-180, 180, -90, 90),
    Snowpack= matrix(runif(4), nrow=2),
    Dr= matrix(runif(4), nrow=2),
    Ds= matrix(runif(4), nrow=2),
    snowmelt_month= matrix(rep.int(0, 4), nrow=2),
    Ws= matrix(runif(4), nrow=2),
    yearmon='201609'
  )

  write_lsm_values_to_cdf(state, fname, prec='double')
  expect_true(file.exists(fname))

  state2 <- read_state_from_cdf(fname)
  expect_equal(state2, state, check.attributes=FALSE)

  file.remove(fname)
})

test_that('we can read forcing from netCDF', {
  fname <- tempfile()

  forcing <- make_forcing(
    extent=c(-180, 180, -90, 90),
    pWetDays=matrix(rep.int(1, 4), nrow=2),
    T=matrix(rep.int(NA, 4), nrow=2),
    Pr=matrix(runif(4), nrow=2)
  )

  wsim.lsm::write_lsm_values_to_cdf(forcing, fname, prec='double')
  forcing2 <- read_forcing_from_cdf(fname)

  expect_equal(forcing2, forcing, check.attributes=FALSE)

  file.remove(fname)
})

test_that('some forcing unit errors can be caught', {
  fname <- tempfile(fileext = '.nc')

  forcing <- make_forcing(
    extent=c(-180, 180, -90, 90),
    pWetDays=matrix(rep.int(1, 4), nrow=2),
    T=matrix(runif(4, min = -17, max = 33), nrow=2),
    Pr=matrix(runif(4), nrow=2)
  )

  # oops! values were already in degrees C, not Kelvin
  forcing$T <- forcing$T - 273.15

  wsim.lsm::write_lsm_values_to_cdf(forcing, fname, prec='double')

  expect_error(
    read_forcing_from_cdf(fname, '202109'),
    '4 T values below allowable minimum'
  )

  file.remove(fname)
})

test_that('we can write model results to netCDF', {
  static <- list(
    elevation=matrix(seq(0, 800, 100), nrow=3),
    flow_directions=matrix(rep.int(as.integer(NA), 9), nrow=3),
    Wc=matrix(rep.int(150, 9), nrow=3)
  )

  forcing <- make_forcing(
    extent=c(-180, 180, -90, 90),
    pWetDays=matrix(rep.int(1, 9), nrow=3),
    T=matrix(runif(9), nrow=3),
    Pr=matrix(runif(9), nrow=3)
  )

  state <- make_state(
    extent=c(-180, 180, -90, 90),
    Snowpack= matrix(runif(9), nrow=3),
    Dr= matrix(runif(9), nrow=3),
    Ds= matrix(runif(9), nrow=3),
    snowmelt_month= matrix(rep.int(0, 9), nrow=3),
    Ws= static$Wc * runif(1),
    yearmon='201609'
  )

  iter <- wsim.lsm::run(static, state, forcing)

  fname <- tempfile(fileext='.nc')
  wsim.lsm::write_lsm_values_to_cdf(iter$obs, fname, prec='double')

  wsim.lsm::write_lsm_values_to_cdf(state, fname, prec='double')

  expect_true(TRUE)

  file.remove(fname)
})

