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

require(testthat)

context('Time-integration regression tests')

test_that('This module performs time-integration equivalently to previous WSIM code', {
  isciences_internal()

  # Load up 6 months of observed data
  root <- '/mnt/fig/WSIM/WSIM_derived_V1.2/Observed/SCI/'
  param <- 'Bt_RO'

  input_files <- wsim.io::expand_inputs(paste0(testdata, '/Bt_RO_trgt20160[1-6].img'))
  inputs <- raster::brick(sapply(input_files, raster::raster))

  # Integrate the 6 months of data
  summaries <- c('Min', 'Max', 'Sum')

  integrated <- rsapply(inputs, function(vals) {
    c( min(vals), max(vals), sum(vals) )
  }, names=summaries)

  # Load up data integrated by previous code
  expected_files <- paste0(testdata, '/', param, '_', summaries, '_6mo_trgt201606.img')
  expected <- raster::brick(sapply(expected_files, raster::raster))
  names(expected) <- summaries

  expect_same_extent_crs(integrated, inputs)

  # Verify that integrated outputs match what was previously computed
  expect_equal(raster::values(integrated$Min), raster::values(expected$Min))
  expect_equal(raster::values(integrated$Max), raster::values(expected$Max))
  expect_equal(raster::values(integrated$Sum), raster::values(expected$Sum), tolerance=1e-7)
})

test_that('This module computes pWetDays equivalently to previous WSIM code', {
  isciences_internal()

  # Subtract 1 from precip values (which are in tenths of millimeters) to ignore "trace" precip
  inputs <- wsim.io::expand_inputs(paste0(testdata, '/*201705*.RT::1@[x-1]->Pr'))
  data <- wsim.io::read_vars_to_cube(inputs)

  pWetDays <- (find_stat('fraction_defined_above_zero'))(data)

  expected <- wsim.io::read_vars(paste0(testdata, '/pWetDays_201705.img'))$data[[1]]

  expect_equal(pWetDays, expected, tolerance=1e-3, check.attributes=FALSE)
})
