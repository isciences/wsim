# Copyright (c) 2019 ISciences, LLC.
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

context('Utility functions')

test_that('coalesce fills NAs with a constant', {
  dat <- array(runif(100), dim=c(5, 20))
  dat[sample.int(100, size=10)] <- NA

  dat2 <- coalesce(dat, -1)

  expect_equal(dim(dat), dim(dat2))
  expect_equal(which(is.na(dat)),
               which(dat2 == -1))
})

test_that('coalesce fills NAs from an equally-sized array', {
  dat <- rbind(
    c(1,  4,   7),
    c(2, NA,  NA),
    c(NA, 6,   9)
  )

  fill <- rbind(
    c(NA, NA,  NA),
    c(2,   5,   8),
    c(NA,  12, 22)
  )

  filled <- rbind(
    c(1,  4, 7),
    c(2,  5, 8),
    c(NA, 6, 9)
  )

  expect_equal(coalesce(dat, fill),
               filled)
})

test_that('coalesce errors out for bad inputs', {
  dat <- matrix(1:4, nrow=2)

  expect_error(
    coalesce(dat, numeric(0)), 'must be a constant or .* same size'
  )

  expect_error(
    coalesce(dat, matrix(1:6, nrow=2), 'must be a constant or .* same size')
  )
})

test_that('we can convert forcing units to those required by the model', {
  expect_equal(5, precip_mm(5, 'mm'))
  expect_equal(5, precip_mm(0.5, 'cm'))
  expect_equal(5, precip_mm(1.929012e-06, 'mm/s', 30, 'days'), tolerance=1e-6)
  expect_equal(5, precip_mm(1.929012e-06, 'kg/m^2/s', 30, 'days'), tolerance=1e-6)

  expect_equal(5, temp_celsius(5, 'degree_Celsius'))
  expect_equal(5, temp_celsius(278.15, 'K'))
})
