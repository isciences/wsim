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

require(testthat)

context("Reading netCDF files (subsets)")

test_that('we can read a specific 2d portion of a variable from a netCDF', {
  fname <- tempfile(fileext='.nc')

  write_vars_to_cdf(list(
    var1= matrix(1:9, nrow=3, ncol=3, byrow=TRUE),
    var2= matrix(21:29, nrow=3, ncol=3, byrow=TRUE)
  ), filename=fname, extent=c(0,1,0,1))

  # Both dimensions offset and count
  lr <- read_vars_from_cdf(fname, offset=c(2,2), count=c(2,2))

  expect_equal(lr$data$var1, rbind(c(5,6), c(8,9)), check.attributes=FALSE)
  expect_equal(lr$data$var2, rbind(c(25,26), c(28,29)), check.attributes=FALSE)

  # Only one dimension specified for count
  middle_col <- read_vars_from_cdf(fname, offset=c(2, 1), count=c(1, -1))
  expect_equal(middle_col$data$var1, rbind(2, 5, 8), check.attributes=FALSE)

  # Neither dimension specified for count
  right_col <- read_vars_from_cdf(fname, offset=c(3, 1), count=c(-1, -1))
  expect_equal(right_col$data$var1, rbind(3, 6, 9), check.attributes=FALSE)

  # Error if offset/count not specified together
  expect_error(lr <- read_vars_from_cdf(fname, offset=c(2,2)))
  expect_error(lr <- read_vars_from_cdf(fname, count=c(1,1)))

  # Error if wrong number of dimensions in offset or count
  expect_error(lr <- read_vars_from_cdf(fname, offset=c(1,2,3), count=c(2,2,2)))

  file.remove(fname)
})

test_that('data extent is correctly set when reading a 2D subset of a netCDF', {
  fname <- tempfile(fileext='.nc')

  write_vars_to_cdf(list(data=matrix(1, nrow=360, ncol=720)),
                    extent=c(-180, 180, -90, 90),
                    filename=fname)

  one_degree_square <- read_vars(fname, offset=c(214, 92), count=c(2,2))
  expect_equal(one_degree_square$extent, c(-73.5, -72.5, 43.5, 44.5), check.attributes=FALSE)

  half_degree_square <- read_vars(fname, offset=c(214, 92), count=c(1,1))
  expect_equal(half_degree_square$extent, c(-73.5, -73.0, 44.0, 44.5), check.attributes=FALSE)

  file.remove(fname)
})

test_that('2D subsets are read correctly when y-inversion is required', {
  fname <- tempfile(fileext='.nc')

  data <- matrix(1:100, nrow=10, byrow=TRUE)

  lats <- seq(0.5, 9.5, by=1.0)
  lons <- seq(0.5, 9.5, by=1.0)

  latdim <- ncdf4::ncdim_def("lat", units="degrees_north", vals=as.double(lats), longname="Latitude", create_dimvar=TRUE)
  londim <- ncdf4::ncdim_def("lon", units="degrees_east", vals=as.double(lons), longname="Longitude", create_dimvar=TRUE)

  var <- ncdf4::ncvar_def(name="data", units="", dim=list(londim, latdim))

  ncout <- ncdf4::nc_create(fname, list(var))
  ncdf4::ncvar_put(ncout, var, t(data[nrow(data):1,]))
  ncdf4::nc_close(ncout)

  expect_equal(read_vars_from_cdf(fname)$data[[1]], data, check.attributes=FALSE)

  expect_equal(
    read_vars_from_cdf(fname)$extent
    ,
    c(0, 10, 0, 10)
  )

  expect_equal(
    read_vars_from_cdf(fname, offset=c(2,2), count=c(2,2))$data[[1]]
    ,
    rbind( c(12, 13), c(22, 23) )
  )

  expect_equal(
    read_vars_from_cdf(fname, offset=c(2,2), count=c(2,2))$extent,
    c(1, 3, 7, 9)
  )

  expect_equal(
    read_vars_from_cdf(fname, offset=c(1, 1), count=c(1,1))$data[[1]]
    ,
    matrix(1)
  )

  expect_equal(
    read_vars_from_cdf(fname, offset=c(1, 1), count=c(1,1))$extent,
    c(0, 1, 9, 10)
  )

  file.remove(fname)
})

test_that('we can retrieve a vertical slice of a file', {
  fname <- tempfile(fileext='.nc')

  data <- array(1:(10*5*7), dim=c(10, 5, 7))

  latdim <- ncdf4::ncdim_def("lat", units="degrees_north", vals=as.double(10:1)-0.5)
  londim <- ncdf4::ncdim_def("lon", units="degrees_east", vals=as.double(1:5)-0.5)
  elevdim <- ncdf4::ncdim_def("elev", units="fathoms", vals=as.double(1:7)-0.5)

  pressure <- ncdf4::ncvar_def(name="Pressure", units="kPa", dim=list(londim, latdim, elevdim))

  ncout <- ncdf4::nc_create(fname, list(pressure))

  ncdf4::ncvar_put(ncout, pressure, aperm(data, c(2,1,3)))

  ncdf4::nc_close(ncout)

  # Read a single vertical slice
  slice <- read_vars_from_cdf(fname, offset=c(1,1,3), count=c(-1,-1,1))
  expect_equal(data[,,3], slice$data[[1]], check.attributes=FALSE)

  # Read a vertical slice using higher-level extra_dims API
  slice <- read_vars_from_cdf(fname, extra_dims=list(elev=2.5))
  expect_equal(data[,,3], slice$data[[1]], check.attributes=FALSE)

  file.remove(fname)
})

test_that('we can use extra_dims arg to read from a N-D array', {
  fname <- tempfile(fileext='.nc')

  data <- array(1:(10*5*7), dim=c(10, 5, 7))
  data_with_quantiles <- abind::abind(data*0.9, data, data*1.1, rev.along=0)

  latdim <- ncdf4::ncdim_def("lat", units="degrees_north", vals=as.double(10:1)-0.5)
  londim <- ncdf4::ncdim_def("lon", units="degrees_east", vals=as.double(1:5)-0.5)
  elevdim <- ncdf4::ncdim_def("elev", units="fathoms", vals=as.double(1:7)-0.5)
  qdim <- ncdf4::ncdim_def("quantile", units="", vals=c(0.25, 0.5, 0.75))

  pressure <- ncdf4::ncvar_def(name="Pressure", units="kPa", dim=list(londim, latdim, elevdim, qdim), prec='double')
  pressure_sqrt <- ncdf4::ncvar_def(name="Pressure_sqrt", units="kPa", dim=list(londim, latdim, elevdim, qdim), prec='double')

  ncout <- ncdf4::nc_create(fname, list(pressure, pressure_sqrt))

  ncdf4::ncvar_put(ncout, pressure, aperm(data_with_quantiles, c(2,1,3,4)))
  ncdf4::ncvar_put(ncout, pressure_sqrt, sqrt(aperm(data_with_quantiles, c(2,1,3,4))))

  ncdf4::nc_close(ncout)

  expect_error(
    enchilada <- read_vars_from_cdf(fname),
    "Expected 2 extra dimensions but got 0"
  )

  expect_error(
    slice <- read_vars_from_cdf(fname, extra_dims=list(elev=2.5)),
    "Expected 2 extra dimensions but got 1"
  )

  expect_error(
    slice <- read_vars_from_cdf(fname, extra_dims=list(elev=9.5, quantile=0.5)),
    "Invalid value 9.5 for dimension elev"
  )

  slice <- read_vars_from_cdf(fname, extra_dims=list(elev=2.5, quantile=0.75))

  expect_equal(slice$data$Pressure_sqrt, sqrt(slice$data$Pressure))
  expect_equal(slice$data$Pressure, data[,,3]*1.1, check.attributes=FALSE)

  file.remove(fname)
})
