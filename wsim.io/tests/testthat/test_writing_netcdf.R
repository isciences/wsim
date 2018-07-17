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

context("Writing netCDF files")

test_that("we can write variables and attributes to a netCDF file", {
  fname <- tempfile()
  data <- matrix(runif(4), nrow=2)

  write_vars_to_cdf(list(my_data=data),
                    fname,
                    xmin=-40,
                    xmax=0,
                    ymin=20,
                    ymax=70,
                    attrs=list(list(var="my_data", key="station", val="A"),
                               list(key="yearmon", val="201702")))

  expect_true(file.exists(fname))

  cdf <- ncdf4::nc_open(fname)

  expect_equal(length(cdf$var), 1+1) # include CRS var
  expect_equal(cdf$var[[1]]$name, "my_data")

  expect_equal(ncdf4::ncatt_get(cdf, 0, "yearmon")$value, "201702")
  expect_equal(ncdf4::ncatt_get(cdf, "my_data", "station")$value, "A")

  # Note that our lat-lon input matrix was written to a lon-lat matrix in the netCDF
  expect_equal(ncdf4::ncvar_get(cdf, "my_data"), t(data))

  ncdf4::nc_close(cdf)

  file.remove(fname)
})

test_that("vars can be written from rasters instead of raw matrices", {
  fname <- tempfile()
  data <- matrix(runif(4), nrow=2)
  rast <- raster::raster(data, xmn=-20, xmx=-10, ymn=30, ymx=70)

  write_layer_to_cdf(rast,
                     fname,
                     varname="my_data",
                     attrs=list(list(var="my_data", key="type", val="random"),
                                list(key="file_type", val="results")))

  expect_true(file.exists(fname))

  cdf <- ncdf4::nc_open(fname)

  expect_equal(length(cdf$var), 1+1)
  expect_equal(cdf$var[[1]]$name, "my_data")

  expect_equal(ncdf4::ncatt_get(cdf, 0, "file_type")$value, "results")
  expect_equal(ncdf4::ncatt_get(cdf, "my_data", "type")$value, "random")

  # Note that our lat-lon input matrix was written to a lon-lat matrix in the netCDF
  expect_equal(ncdf4::ncvar_get(cdf, "my_data"), t(data))

  ncdf4::nc_close(cdf)

  file.remove(fname)
})

test_that("crs is implicitly written as a dimensionless variable with no data", {
  fname <- tempfile()

  data <- list(my_data= matrix(runif(9), nrow=3))
  write_vars_to_cdf(data, fname, extent=c(-180, 180, -90, 90))

  v <- read_vars_from_cdf(fname)

  # Only one variable has dimensions
  expect_equal(names(v$data), c("my_data"))

  # CRS is an attribute
  expect_true('crs' %in% names(v$attrs))

  file.remove(fname)
})

test_that("existing files can be appended to", {
  fname <- tempfile()

  data1 <- list(
    temperature= matrix(runif(9), nrow=3)
  )

  data2 <- list(
    pressure= matrix(runif(9), nrow=3)
  )

  extent <- c(-80, -30, 20, 60)
  write_vars_to_cdf(data1, fname, extent=extent)
  write_vars_to_cdf(data2, fname, extent=extent, append=TRUE)

  v <- read_vars_from_cdf(fname)
  expect_equal(names(v$data), c('temperature', 'pressure'))

  file.remove(fname)
})

test_that("we cannot append if dimensions are not the same", {
  fname <- tempfile()

  write_vars_to_cdf(list(data=matrix(runif(9), nrow=3)), fname, extent=c(0, 1, 0, 1))

  expect_error(
    write_vars_to_cdf(list(data2=matrix(runif(9), nrow=3)), fname, extent=c(0, 1, 0, 0.5), append=TRUE),
    "Values .* do not match existing values"
  )

  expect_error(
    write_vars_to_cdf(list(data2=matrix(runif(16), nrow=4)), fname, extent=c(0, 1, 0, 1), append=TRUE),
    "Cannot write .* dimension 4 .* existing file .* dimension 3"
  )

  file.remove(fname)
})

test_that("numeric precision can be specified on a per-variable basis", {
  fname <- tempfile()
  fname <- '/tmp/kansas.nc'

  data <- list(
    my_data= 10*matrix(runif(9), nrow=3),
    my_int_data= 10*matrix(runif(9), nrow=3)
  )

  write_vars_to_cdf(data,
                    fname,
                    extent=c(0, 1, 0, 1),
                    prec=list(my_data="single",
                              my_int_data="integer"))

  v <- ncdf4::nc_open(fname)
  expect_equal(v$var$my_int_data$prec, "int")
  expect_equal(v$var$my_data$prec, "float")

  expect_equal(v$var$my_int_data$missval, -9999)
  expect_equal(v$var$my_data$missval, -3.4028234663852886e+38)

  ncdf4::nc_close(v)

  file.remove(fname)
})

test_that('write_vars_to_cdf provides useful errors if extent is not correctly specified', {
  fname <- tempfile(fileext='.nc')

  data <- list(
    var= matrix(runif(9), nrow=3)
  )

  expect_error(write_vars_to_cdf(data, fname),
               "Must provide either extent or xmin,")

  expect_error(write_vars_to_cdf(data, fname, extent=c(0, 1, 0, 1), xmin=2),
               "Both extent and xmin.* provided")

  expect_error(write_vars_to_cdf(data, fname, extent=c(1,2,3)),
               "Extent should be provided as")

  expect_error(write_vars_to_cdf(data, fname, extent=c(1, 0, 0, 1)),
               "xmax < xmin")

  expect_error(write_vars_to_cdf(data, fname, extent=c(1, 1, 1, 0)),
               "ymax < ymin")
})

test_that("we can write non-spatial variables and attributes to a netCDF file", {
  fname <- tempfile()
  data <- runif(4)

  write_vars_to_cdf(list(my_data=data),
                    fname,
                    ids=3:6,
                    attrs=list(list(var="my_data", key="station", val="A"),
                               list(key="yearmon", val="201702")))

  expect_true(file.exists(fname))

  cdf <- ncdf4::nc_open(fname)

  expect_equal(length(cdf$dim), 1)
  expect_equal(cdf$dim[[1]]$name, "id")
  expect_equal(cdf$dim[[1]]$vals, 3:6, check.attributes=FALSE)

  expect_equal(length(cdf$var), 1)
  expect_equal(cdf$var[[1]]$name, "my_data")

  expect_equal(ncdf4::ncatt_get(cdf, 0, "yearmon")$value, "201702")
  expect_equal(ncdf4::ncatt_get(cdf, "my_data", "station")$value, "A")

  expect_equal(ncdf4::ncvar_get(cdf, "my_data"), data, check.attributes=FALSE)

  file.remove(fname)
})

test_that('ids must be integers or integer-coercible', {
  fname <- tempfile(fileext='.nc')

  data <- runif(4)

  expect_error(
    write_vars_to_cdf(list(my_data=data),
                      fname,
                      ids=c(3.0, 4.0, 5.0, 6.1)))

  write_vars_to_cdf(list(my_data=data),
                    fname,
                    ids=c(3.0, 4.0, 5.0, 6.0))

  file.remove(fname)
})
