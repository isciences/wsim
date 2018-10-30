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

context('Basin integration period')

bins <- c(1, 3, 6, 12, 24, 36) 

test_that('when there is no upstream storage, we use a 1-month integration period', {
  expect_equal(basin_integration_period(0, 100, bins), 1)  
})

test_that('when there is less than 1 month of upstream storage, we use a 1-month integration period', {
  expect_equal(basin_integration_period(99, 100, bins), 1)
})

test_that('when there is less than 3 months of upstream storage, we use a 1-month integration period', {
  expect_equal(basin_integration_period(299, 100, bins), 1)
})

test_that('when there are [3, 6) months of upstream storage, we use a 3-month integration period', {
  expect_equal(basin_integration_period(300, 100, bins), 3)
  expect_equal(basin_integration_period(599, 100, bins), 3)
})

test_that('when there are more than 36 months of upstream storage, we use a 36-month integration period', {
  expect_equal(basin_integration_period(100000, 100, bins), 36)
})
