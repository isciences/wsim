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

context('Loss function')

test_that('Loss function behaves as expected', {
  # no loss at or below lower threshold return period
  expect_equal(0, loss_function(5, 6, 100, 2))
  expect_equal(0, loss_function(6, 6, 100, 2))
  
  # total loss at or above upper threshold return period
  expect_equal(1, loss_function(70, 6, 70, 2))
  expect_equal(1, loss_function(71, 6, 70, 2))
  
  # losses increase with return period
  expect_true(!is.unsorted(loss_function(6:70, 6, 70, 2)))
  
  # NA propagation
  expect_equal(c(0, NA_real_, 1),
               loss_function(c(6, NA, 70), 6, 70, 2))
  
  # preserves dimensions
  expect_equal(c(3, 7, 2), dim(loss_function(array(9, dim=c(3, 7, 2)), 6, 70, 2)))
})