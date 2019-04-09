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

context('Loss simulation functions')

test_that('random loss returns a single value', {
  expect_length(random_loss(n_surplus=2, n_deficit=2, independent=FALSE, combine_with='max', 12, 80, 2), 1)  
})

test_that('simulation returns expected structure', {
  df <- simulate_expected_loss(10, 'sum', 12, 80, 2)
  
  expect_equal(names(df),
               c('season_length_months',
                 'method',
                 'inputs',
                 'mean_loss',
                 'sd_loss'))
  expect_length(df$method, 12 * 2 * 2)
})

test_that('we get an error when an unsupported combine method is specified', {
  expect_error(
    simulate_expected_loss(10, 'mode', 12, 80, 2),
    'Unknown.*method'
  )
})