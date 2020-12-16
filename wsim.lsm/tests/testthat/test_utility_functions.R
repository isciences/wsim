# Copyright (c) 2019-2020 ISciences, LLC.
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

test_that('cell areas are computed correctly', {
  dims <- c(360, 720)
  extent <- c(-180, 180, -90, 90)

  area_hlf_deg <- cell_areas_m2(extent, dims)

  expect_equal(unname(area_hlf_deg[108, 17]), 2492775206)
})

test_that('date calculations are correct', {
  expect_equal(next_yyyymm('201612'), '201701')
  expect_equal(next_yyyymm('201701'), '201702')

  expect_equal(days_in_yyyymm('201701'), 31)
  expect_equal(days_in_yyyymm('201702'), 28)
  expect_equal(days_in_yyyymm('201602'), 29)

  expect_equal(add_months('201612', 1), '201701')
  expect_equal(add_months('201612', 13), '201801')
  expect_equal(add_months('201612', -1), '201611')
  expect_equal(add_months('201612', -13), '201511')
  expect_equal(add_months('201612', -25), '201411')

  expect_equal(doy_to_month(1), 1)
  expect_equal(doy_to_month(31), 1)
  expect_equal(doy_to_month(32), 2)

  expect_equal(doy_to_month(matrix(c(1, 31, 32, 37), nrow=2)),
               matrix(c(1, 1, 2, 2), nrow=2))
})

test_that('we can compute daylength', {
  daylength <- day_length_matrix(2017, 02, c(-180, 180, -90, 90), 181, 1)

  expect_true(!any(is.na(daylength)))
  expect_true(!any(daylength < 0 | daylength > 1))

  expect_equal(daylength[1], 0)    # dark at the north pole
  expect_equal(daylength[181], 1)  # light at the south pole
  expect_equal(daylength[91], 0.5) # 12 hours of light at the equator
})

test_that('precision is correctly converted to digits before/after decimal point', {
  expect_equal(digits_for_res(0.1), 1)
  expect_equal(digits_for_res(0.11), 1)
  expect_equal(digits_for_res(0.09999999), 2)

  expect_equal(digits_for_res(1500), -3)
})

test_that('mm precision is converted to m3 precision using cell area at equator', {
  extent <- c(-180, 180, -90, 90)
  dims <- c(360, 720)

  expect_equal(digits_for_res(res_mm_to_m3(0.1, extent, dims)),
               -5)
})
