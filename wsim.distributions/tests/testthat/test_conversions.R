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

context("Anomaly conversions")

test_that('We can convert between standardized anomalies and return periods', {
  # Expected return period
  # Source: WSIM_derived_V1.2/Observed/Freq/Bt_RO_Max_24mo_freq/Bt_RO_Max_24mo_freq_trgt198402.img
  # Cell 42, 59
  expected_return_period <- -2.483

  zscore <- -0.246
  return_period <- sa2rp(zscore)

  expect_equal(return_period, expected_return_period, tolerance=1e-3)
  expect_equal(zscore, rp2sa(return_period))
})

test_that('We can convert between quantiles and return periods', {
  expect_equal(rp2quantile(-15), 1/15)
  expect_equal(rp2quantile(15), 1-1/15)

  expect_equal(-15, quantile2rp(1/15))
  expect_equal(15,  quantile2rp(1 - 1/15))
})
