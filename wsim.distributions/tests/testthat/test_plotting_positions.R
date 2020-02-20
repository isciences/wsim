# Copyright (c) 2020 ISciences, LLC.
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

library(testthat)

context("Plotting positions")

test_that('quantile adjustment is correct', {
  # when range spans the median, use the median
  # standardized anomaly must be zero if range of ranks
  # allows above-median and below-median values
  expect_equal(0.5, adjusted_quantile(0.4, 0.6))

  # when range is above median, use lower bound of range
  # (minimize absolute value of standardized anomaly)
  expect_equal(0.6, adjusted_quantile(0.6, 0.8))

  # when range is below median, use upper bound of range
  # (minimize absolute value of standardized anomaly)
  expect_equal(0.4, adjusted_quantile(0.1, 0.4))
})

test_that('Tukey plotting position is correct', {
  # second argument is the number of observations *excluding* the one
  # we are computing a probability for
  probs <- plotting_position_tukey(1:11, 10)

  # middle rank is the median
  expect_equal(probs[6], 0.5)

  # probabilities are symmetrical on either side of the median
  expect_equal(probs[1:5], 1 - probs[11:7])
})
