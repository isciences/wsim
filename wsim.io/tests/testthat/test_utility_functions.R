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
require(wsim.io)

context("Utility functions")

test_that('cube_to_matrices transforms a 3d array into a list of matrices', {
  arr <- array(runif(36), dim=c(4,3,3))

  mats <- cube_to_matrices(arr)

  expect_length(mats, 3)
  expect_equal(mats[[1]], arr[,,1])
  expect_equal(mats[[2]], arr[,,2])
  expect_equal(mats[[3]], arr[,,3])
})

test_that('cube_to_matrices avoids dropping dimensions', {
  arr <- array(runif(12), dim=c(4, 1, 3))

  mats <- cube_to_matrices(arr)

  expect_true(all(sapply(mats, is.matrix)))
})

test_that('latlon sequences are correct', {
  extent <- c(-180, 180, -90, 90)
  dims <- c(720, 1440)

  lats <- lat_seq(extent, dims)
  lons <- lon_seq(extent, dims)

  # sequence have correct length
  expect_length(lons, 1440)
  expect_length(lats, 720)

  # latitude is N to S
  expect_equal(lats, rev(sort(lats)))

  # longitude is W to E
  expect_equal(lons, sort(lons))

  # spacing is correct
  expect_equal(lats[1] - lats[2], 0.25)
  expect_equal(lons[2] - lons[1], 0.25)

  # coordinates represent grid centers
  expect_equal(lats[1], 89.875)
  expect_equal(lons[1], -179.875)
})

test_that('integer coercion works', {
  expect_true(is.integer(coerce_to_integer(1L)))
  expect_true(is.integer(coerce_to_integer(1)))
})

test_that('integer coercion throws an error with an out-of-range input', {
  expect_error(coerce_to_integer(.Machine$integer.max + 1),
               'Values \\(\\d+\\) cannot be coerced')
})

test_that('integer coercion throws an error with non-integer floats', {
  expect_error(coerce_to_integer(.Machine$integer.max + 1),
               'Values \\(\\d+\\) cannot be coerced')
})

test_that('bin assignment works as expected', {
  expect_equal(assign_to_bin(vals=c(0.5, 1, 1.5, 2, 3, 4),
                             bins=c(1, 2, 3)),
               c(1, 1, 1, 2, 3, 3))

  expect_equal(assign_to_bin(vals=c(0.5, 1, 1.5, 2, 3, 4),
                             bins=c(2, 1, 3)),
               c(1, 1, 1, 2, 3, 3))
})
