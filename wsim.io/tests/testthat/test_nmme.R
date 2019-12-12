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

require(testthat)

context("Reading NMME files")

test_that('we can convert between dates and NMME "Forecast Start Time"', {
  expect_equal(0, months_since_jan_1960('196001'))
  expect_equal(1, months_since_jan_1960('196002'))
  expect_equal(14, months_since_jan_1960('196103'))

  expect_equal('196001', yearmon_from_months_since_jan_1960(0))
  expect_equal('196002', yearmon_from_months_since_jan_1960(1))
  expect_equal('196103', yearmon_from_months_since_jan_1960(14))

  expect_error(months_since_jan_1960(NA))
  expect_error(months_since_jan_1960(NULL))
  expect_error(months_since_jan_1960('20191'))

  expect_error(yearmon_from_months_since_jan_1960(NA))
  expect_error(yearmon_from_months_since_jan_1960(NULL))
  expect_error(yearmon_from_months_since_jan_1960(2.2))
})

test_that('we can compute the number of lead months', {
  expect_equal(0.5, lead_months('201701', '201701'))
  expect_equal(2.5, lead_months('194912', '195002'))

  expect_error(lead_months('195002', '194912'))
})

test_that('NMME grid is correctly converted to half-degree', {
  fname <- tempfile(fileext='.nc')

  lons <- seq(0, 359, 1)
  lats <- seq(90, -90, -1)
  n <- length(lats)*length(lons)

  data <- matrix(0:(n-1), ncol=length(lons), byrow=TRUE)

  dims <- list(
    lon = ncdf4::ncdim_def('lon', 'degrees_east', lons),
    lat = ncdf4::ncdim_def('lat', 'degrees_north', lats)
  )

  vars <- list(
    test = ncdf4::ncvar_def('test', 'none', dim=dims[c('lon', 'lat')])
  )

  nc <- ncdf4::nc_create(fname, vars)
  ncdf4::ncvar_put(nc, vars$test, t(data))
  ncdf4::nc_close(nc)

  data_in <- read_vars_from_cdf(fname)$data[[1]]
  expect_equal(dim(data_in), dim(data))

  # lons wrapped correctly
  expect_equal(data_in[1, ], c(181:359, 0:180))
  expect_equal(data_in[2, ], 360+data_in[1, ])

  data_halfdeg <- nmme_to_halfdeg(data_in)

  expect_equal(dim(data_halfdeg), c(360, 720))

  expect_equal(data_halfdeg[1, ],
               c(180, rep(181:359, each=2), rep(0:179, each=2), 180))

  # interior rows duplicated
  expect_equal(data_halfdeg[2, ], data_halfdeg[1, ] + 360)
  expect_equal(data_halfdeg[3, ], data_halfdeg[1, ] + 360)

  file.remove(fname)
})
