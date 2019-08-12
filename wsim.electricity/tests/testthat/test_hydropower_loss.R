# Copyright (c) 2018-2019 ISciences, LLC.
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

context('Hydropower loss')

test_that('When flow is equal to or greater than expected flows, there is no loss', {
  expect_equal(hydropower_loss(100, 100), 0)  
  expect_equal(hydropower_loss(110, 100), 0)  
})

test_that('Loss increases as flow decreases from expected', {
  losses <- hydropower_loss(30:0, rep.int(30, 31))
  
  expect_equal(sum(losses == 1), 1) # only have total loss for zero flow
  expect_true(all(losses >= 0) && all(losses <= 1))
  expect_equal(losses, sort(losses))
})

test_that('Numerical edge cases are handled', {
  expect_equal(1, hydropower_loss(0, 100))
  expect_equal(0, hydropower_loss(Inf, 100))
  expect_equal(0, hydropower_loss(0, 0))
  expect_equal(0, hydropower_loss(1, 0))
  
  expect_identical(NA_real_, hydropower_loss(NA, 100))
  expect_identical(NA_real_, hydropower_loss(NA_real_, 100))
  expect_identical(NA_real_, hydropower_loss(NaN, 100))
})

test_that('Hydropower loss is vectorized in an expected way', {
  expect_equal(
    c(hydropower_loss(1, 50),
      hydropower_loss(2, 50)),
    hydropower_loss(1:2, 50)
  )
})