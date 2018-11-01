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

context('Water-cooled plant loss')

test_that('When there is no water stress, onset is 30 years', {
  expect_equal(water_cooled_loss_onset(0), 30)
})

test_that('When there is maximum water stress, onset is 10 years', {
  expect_equal(water_cooled_loss_onset(1), 10)
})

test_that('Onset return period is linearly interpolated between water stress values', {
  expect_equal(water_cooled_loss_onset(0.3), 17.5)  
})

test_that('At or below the onset return period, there is no loss', {
  expect_equal(water_cooled_loss(10, 10, 100), 0)  
  expect_equal(water_cooled_loss(5,  10, 100), 0)  
})

test_that('At or above the maximum return period, there is complete loss', {
  expect_equal(water_cooled_loss(40, 10, 40), 1.0)  
  expect_equal(water_cooled_loss(45, 10, 40), 1.0)  
})

test_that('Loss increases between the onset and the maximum return periods', {
  losses <- water_cooled_loss(10:40, 10, 40)
  
  expect_true(all(losses >= 0))
  expect_true(all(losses <= 1))
  expect_equal(losses, sort(losses))
})