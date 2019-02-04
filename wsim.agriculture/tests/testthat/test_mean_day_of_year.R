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

context('Mean day-of-year')

test_that('We handle wraparound correctly', {
  expect_equal(357, mean_doy(c(350, 352, 4)))
  expect_equal(3,   mean_doy(c(350, 352, 40)))
  
  # Equivalent computation using 'circular' package:
  # mean.circular(circular((c(350, 352, 40)-1)/365*2*pi))/2/pi*365+365+1
  # mean.circular(circular((c(350, 352, 40)-1)/365*2*pi))/2/pi*365+1
})

test_that('NA values are ignored', {
  expect_equal(3, mean_doy(c(NA, 350, 352, 40, NA, NA, NA)))
})

test_that('Returned values are between 1 and 365', {
  expect_equal(365, mean_doy(c(350, 352, 30)))
  expect_equal(1, mean_doy(c(350, 352, 31)))
})
