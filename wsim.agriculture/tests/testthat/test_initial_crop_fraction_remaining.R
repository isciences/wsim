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

context('Initial crop fraction remaining')

test_that('Regression applied correctly', {
  a <- 2.34e-03
  b <- -2.11e-06
  
  ifrac <- initial_crop_fraction_remaining(1:365, a, b)
  
  expect_true(all(ifrac >= 1))
  expect_false(is.unsorted(ifrac))
  expect_length(ifrac, 365)
})