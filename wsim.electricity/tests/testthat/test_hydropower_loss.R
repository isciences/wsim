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

context('Hydropower loss')

test_that('When flow is equal to or greater than expected flows, there is no loss', {
  expect_equal(hydropower_loss(100, 100, 0.6), 0)  
  expect_equal(hydropower_loss(110, 100, 0.6), 0)  
})

test_that('Loss increases as flow decreases from expected', {
  losses <- hydropower_loss(30:0, 30, 0.6)
  
  expect_equal(sum(losses == 1), 1) # only have total loss for zero flow
  expect_true(all(losses >= 0) && all(losses <= 1))
  expect_equal(losses, sort(losses))
})