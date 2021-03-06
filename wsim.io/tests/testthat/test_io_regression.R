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

require(testthat)
require(wsim.io)

context("I/O Regression Tests")

test_that("We can read a file of NCEP daily precipitation", {
  isciences_internal()

  filename <- file.path(testdata, 'PRCP_CU_GAUGE_V1.0GLB_0.50deg.lnx.20170521.RT')

  precip <- read_vars(filename)$data[[1]]

  precip_rast <- raster::raster(precip, xmn=-180, xmx=180, ymn=-90, ymx=90)

  expect_equal(dim(precip), c(360, 720))       # 0.5-degree lon/lat
  expect_equal(raster::extract(precip_rast, cbind(-73.2, 44.5)), 0, check.attributes=FALSE) # no rain in Burlington, VT
  expect_equal(max(precip, na.rm = TRUE), 1076.367, tolerance=1e-3)
})

test_that("We can read a CFSv2 forecast", {
  isciences_internal()

  filename <- file.path(testdata, 'tmp2m.trgt201706.lead6.ic2016122506.nc')
  forecast <- read_vars_from_cdf(paste0(filename, '::tmp2m@[x-273.13]'))

  forecast_rast <- raster::raster(forecast$data$tmp2m,
                                  xmn=forecast$extent[1],
                                  xmx=forecast$extent[2],
                                  ymn=forecast$extent[3],
                                  ymx=forecast$extent[4])

  # the file used as an example is incorrectly flipped about the y-axis.
  forecast_rast <- raster::flip(forecast_rast, 'y')

  btv_fahrenheit <- raster::extract(forecast_rast, cbind(-73.2, 44.5))*9/5+32

  expect_equal(btv_fahrenheit, 58.96121, tolerance=1e-2, check.attributes=FALSE)
})

test_that("We can read a gridded binary .mon file", {
  isciences_internal()

  filename <- file.path(testdata, 't.201701.mon::1->temp')

  v <- read_vars(filename)

  row_btv <- round((90-44.5)*360/180)  # 0.5-degree cells, starting at north pole
  col_btv <- round((180-73.2)*720/360) # 0.5-degree cells, starting at antimeridian and working east

  expect_equal(v$data$temp[row_btv, col_btv], -3.21, tolerance=1e-3) # 26.2 F in Burlington, VT
  expect_equal(v$extent, c(-180, 180, -90, 90))
})
