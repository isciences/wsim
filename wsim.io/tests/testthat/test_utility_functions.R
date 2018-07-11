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
