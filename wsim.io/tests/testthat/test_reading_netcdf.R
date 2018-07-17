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

context("Reading netCDF files")

test_that("we can read attributes and variables from a spatial netCDF file into matrices", {
  fname <- tempfile(fileext='.nc')
  data <- matrix(runif(4), nrow=2)

  write_vars_to_cdf(list(my_data=data),
                    fname,
                    xmin=-40,
                    xmax=0,
                    ymin=20,
                    ymax=70,
                    attrs=list(list(var="my_data", key="station", val="A"),
                               list(key="yearmon", val="201702")))

  v <- read_vars_from_cdf(fname)

  # Grid extent is returned as xmin, xmax, ymin, ymax
  expect_equal(v$extent, c(-40, 0, 20, 70))

  # Global attributes are accessible in $attrs
  expect_equal(v$attrs$yearmon, "201702")

  # No IDs for spatial data
  expect_null(v$ids)

  # Variable attributes are accessible as attrs of the matrix
  expect_equal(attr(v$data$my_data, 'station'), 'A')

  # Make sure our data didn't get messed up (transposed, etc.)
  expect_equal(v$data$my_data, data, check.attributes=FALSE)

  file.remove(fname)
})

test_that("we can read attributes and variables from a non-spatial netCDF file into matrices", {
  fname <- tempfile(fileext='.nc')
  data <- runif(4)

  write_vars_to_cdf(list(my_data=data),
                    fname,
                    ids=2:5,
                    attrs=list(list(var="my_data", key="station", val="A"),
                               list(key="yearmon", val="201702")))

  v <- read_vars_from_cdf(fname)

  expect_equal(v$ids, 2:5, check.attributes=FALSE)

  # No extent for non-spatial data
  expect_null(v$extent)

  # Global attributes are accessible in $attrs
  expect_equal(v$attrs$yearmon, "201702")

  # Variable attributes are accessible as attrs of the matrix
  expect_equal(attr(v$data$my_data, 'station'), 'A')

  # Make sure our data didn't get messed up (transposed, etc.)
  expect_equal(v$data$my_data, data, check.attributes=FALSE)

  file.remove(fname)
})

test_that("we can check for expected IDs when loading a non-spatial netCDF", {
  fname <- tempfile(fileext='.nc')
  data <- runif(10)

  write_vars_to_cdf(list(data=data), fname, ids=11:20)

  expect_error(read_vars(fname, expect.ids=10:19),
               "Unexpected IDs")

  file.remove(fname)
})

test_that("variables that have no dimensions are read in as attributes", {
  fname <- tempfile(fileext='.nc')

  latdim <- ncdf4::ncdim_def("lat", units="degrees_north", vals=as.double(1:20), longname="Latitude", create_dimvar=TRUE)
  londim <- ncdf4::ncdim_def("lon", units="degrees_east", vals=as.double(30:70), longname="Longitude", create_dimvar=TRUE)

  ncvars <- list(
    crs= ncdf4::ncvar_def(name="crs", units="", dim=list(), missval=NULL, prec="integer"),
    pressure= ncdf4::ncvar_def(name="Pressure", units="kPa", dim=list(latdim, londim))
  )

  ncout <- ncdf4::nc_create(fname, ncvars)
  ncdf4::ncatt_put(ncout, "crs", "code", "EPSG:4326")
  ncdf4::nc_close(ncout)

  v <- read_vars_from_cdf(fname)

  # We only read out one variable, because only one variable has dimensions
  expect_equal(names(v$data), c("Pressure"))

  # The dimenionless variable is read in as attributes
  expect_equal(v$attrs$crs$code, "EPSG:4326")

  file.remove(fname)
})

test_that("we can read only a subset of variables from a netCDF", {
  fname <- tempfile(fileext='.nc')

  data <- list(
    location= matrix(runif(9), nrow=3),
    scale= matrix(runif(9), nrow=3),
    shape= matrix(runif(9), nrow=3)
  )

  write_vars_to_cdf(data, fname, extent=c(-70, -30, 20, 60), attrs=list())

  v <- read_vars_from_cdf(fname, vars=c('scale', 'shape'))

  expect_equal(names(v$data), c('scale', 'shape'))

  file.remove(fname)
})

test_that("we can transform and rename variables", {
  fname <- tempfile(fileext='.nc')

  data <- list(
    reflectance= matrix(1:9, nrow=3)
  )

  write_vars_to_cdf(data, fname, extent=c(0, 1, 0, 1))

  v <- read_vars_from_cdf(paste0(fname, '::reflectance@negate->ref'))

  expect_equal(v$data$ref, -data$reflectance, check.attributes=FALSE)

  file.remove(fname)
})

test_that("we can read multiple spatial variables into a cube", {
  fname <- tempfile(fileext='.nc')

  data <- list(
    location= matrix(runif(9), nrow=3),
    scale= matrix(runif(9), nrow=3),
    shape= matrix(runif(9), nrow=3)
  )

  extent <- c(20, 80, 30, 70)

  write_vars_to_cdf(data, fname, extent=extent)

  cube <- read_vars_to_cube(fname)

  expect_equal(attr(cube, "extent"), extent)
  expect_equal(cube[,,"location"], data$location)
  expect_equal(cube[,,"scale"], data$scale)
  expect_equal(cube[,,"shape"], data$shape)

  expect_equal(dimnames(cube)[[3]], c('location', 'scale', 'shape'))

  file.remove(fname)
})

test_that("we can read multiple non-spatial variables into a cube", {
  fname <- tempfile(fileext='.nc')

  write_vars_to_cdf(
    list(
      location=runif(8),
      scale=runif(8),
      shape=runif(8)),
    ids=2:9,
    filename=fname
  )

  data <- read_vars_to_cube(fname)
  expect_equal(attr(data, 'ids'), 2:9, check.attributes=FALSE)

  file.remove(fname)
})

test_that("we can read fits from multiple netCDFs", {
  fname1 <- tempfile(fileext='.nc')
  fname2 <- tempfile(fileext='.nc')

  data <- function() {
    list(
      location= matrix(runif(9), nrow=3),
      scale= matrix(runif(9), nrow=3),
      shape= matrix(runif(9), nrow=3)
    )
  }

  write_vars_to_cdf(data(), fname1, extent=c(0, 1, 0, 1))

  # Error because variable name is undefined
  expect_error(read_fits_from_cdf(fname1))

  write_vars_to_cdf(data(), fname1, extent=c(0, 1, 0, 1), attrs=list(list(key="variable", val="rainfall")))

  #Expect error because distribution name is undefined
  expect_error(read_fits_from_cdf(fname1))

  # Expect error because extents differ
  write_vars_to_cdf(data(), fname1, extent=c(0, 1, 0, 1), attrs=list(list(key="distribution", val="pe3"),
                                                                     list(key="variable", val="rainfall")))
  write_vars_to_cdf(data(), fname2, extent=c(0, 2, 0, 1), attrs=list(list(key="distribution", val="gev"),
                                                                     list(key="variable", val="temperature")))
  capture.output(
    expect_error(read_fits_from_cdf(c(fname1, fname2)))
  )

  # Should work this time
  write_vars_to_cdf(data(), fname1, extent=c(0, 1, 0, 1), attrs=list(list(key="distribution", val="pe3"),
                                                                     list(key="variable", val="rainfall")))
  write_vars_to_cdf(data(), fname2, extent=c(0, 1, 0, 1), attrs=list(list(key="distribution", val="gev"),
                                                                     list(key="variable", val="temperature")))

  capture.output(
    fits <- read_fits_from_cdf(c(fname1, fname2))
  )

  expect_named(fits, c('rainfall', 'temperature'), ignore.order=TRUE)
  expect_equal(dim(fits[['rainfall']]), c(3,3,3))
  expect_equal(dim(fits[['temperature']]), c(3,3,3))
  expect_equal(dimnames(fits[['rainfall']])[[3]], c('location', 'scale', 'shape'))

  file.remove(fname1)
  file.remove(fname2)
})

test_that('we get a helpful error message when trying to access data that does not exist', {
  for (f in c('sdfy.nc::sdf', 'sdgy.tif', 'dsaf.mon')) {
    expect_error(read_vars(f), 'does not exist')
  }
})

test_that("we can expect a specific number of variables in a file", {
  fname <- tempfile(fileext='.nc')

  data <- list(
    location= matrix(runif(9), nrow=3),
    scale= matrix(runif(9), nrow=3),
    shape= matrix(runif(9), nrow=3)
  )
  write_vars_to_cdf(data, fname, extent=c(0, 1, 0, 1))

  expect_error(read_vars(fname, expect.nvars=1))
  ok <- read_vars(fname, expect.nvars=3)

  file.remove(fname)
})

test_that("we can expect a specific extent for a file", {
  fname <- tempfile(fileext='.nc')

  data <- list(
    location= matrix(runif(9), nrow=3),
    scale= matrix(runif(9), nrow=3),
    shape= matrix(runif(9), nrow=3)
  )
  write_vars_to_cdf(data, fname, extent=c(0, 1, 0, 1))

  expect_error(read_vars(fname, expect.extent=c(0, 2, 0, 1)))
  ok <- read_vars(fname, expect.extent=c(0, 1, 0, 1))

  file.remove(fname)
})

test_that("we can expect specific dimensions for a file", {
  fname <- tempfile(fileext='.nc')

  data <- list(
    location= matrix(runif(9), nrow=3),
    scale= matrix(runif(9), nrow=3),
    shape= matrix(runif(9), nrow=3)
  )
  write_vars_to_cdf(data, fname, extent=c(0, 1, 0, 1))

  expect_error(read_vars(fname, expect.dims=c(3, 4)))
  ok <- read_vars(fname, expect.dims=c(3, 3))

  file.remove(fname)
})

test_that("dimnames preserved with a complex vardef", {
  tempfile_root <- tempfile()

  fname1 <- paste0(tempfile_root, '_201711.nc')
  fname2 <- paste0(tempfile_root, '_201710.nc')

  data <- list(
    location= matrix(runif(9), nrow=3),
    scale= matrix(runif(9), nrow=3),
    shape= matrix(runif(9), nrow=3)
  )

  extent <- c(20, 80, 30, 70)

  write_vars_to_cdf(data, fname1, extent=extent)
  write_vars_to_cdf(data, fname2, extent=extent)

  cube <- wsim.io::read_vars_to_cube(expand_inputs(paste0(tempfile_root, '_[201710:201711].nc::location,shape')))

  expect_equal(dimnames(cube)[[3]], c('location', 'shape', 'location', 'shape'))

  file.remove(fname1)
  file.remove(fname2)
})

test_that("we can read multiple variables from a netCDF into a RasterBrick", {
  fname <- tempfile(fileext='.nc')

  data <- list(
    location= matrix(runif(9), nrow=3),
    scale= matrix(runif(9), nrow=3),
    shape= matrix(runif(9), nrow=3)
  )

  write_vars_to_cdf(data, fname, extent=c(-70, -30, 20, 60), attrs=list(list(key="distribution", val="fake")))

  brick <- read_brick_from_cdf(paste0(fname, '::location,scale'))

  expect_s4_class(brick, "RasterBrick")
  expect_equal(raster::metadata(brick)$distribution, "fake")
  expect_equal(names(brick), c("location", "scale"))
  file.remove(fname)
})