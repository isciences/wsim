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

context("netCDF functions")

test_that("it can write variables and attributes to a netCDF file", {
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

test_that("we can read attributes and variables from a netCDF file into matrices", {
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

  v <- read_vars_from_cdf(fname)

  # Grid extent is returned as xmin, xmax, ymin, ymax
  expect_equal(v$extent, c(-40, 0, 20, 70))

  # Global attributes are accessible in $attrs
  expect_equal(v$attrs$yearmon, "201702")

  # Variable attributes are accessible as attrs of the matrix
  expect_equal(attr(v$data$my_data, 'station'), 'A')

  # Make sure our data didn't get messed up (transposed, etc.)
  expect_equal(v$data$my_data, data, check.attributes=FALSE)

  file.remove(fname)
})

test_that("variables that have no dimensions are read in as attributes", {
  fname <- tempfile()

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

test_that("we can read only a subset of variables from a netCDF", {
  fname <- tempfile()

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
  fname <- tempfile()

  data <- list(
    reflectance= matrix(1:9, nrow=3)
  )

  write_vars_to_cdf(data, fname, extent=c(0, 1, 0, 1))

  v <- read_vars_from_cdf(paste0(fname, '::reflectance@negate->ref'))

  expect_equal(v$data$ref, -data$reflectance, check.attributes=FALSE)

  file.remove(fname)
})

test_that("we can read multiple variables into a cube", {
  fname <- paste0(tempfile(), '.nc')

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
  fname <- tempfile()

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

test_that("we can expect a specific number of variables in a file", {
  fname <- paste0(tempfile(), '.nc')

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
  fname <- paste0(tempfile(), '.nc')

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
  fname <- paste0(tempfile(), '.nc')

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

test_that("we can read fits from multiple netCDFs", {
  fname1 <- paste0(tempfile(), '.nc')
  fname2 <- paste0(tempfile(), '.nc')

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
  expect_error(read_fits_from_cdf(c(fname1, fname2)))

  # Should work this time
  write_vars_to_cdf(data(), fname1, extent=c(0, 1, 0, 1), attrs=list(list(key="distribution", val="pe3"),
                                                                     list(key="variable", val="rainfall")))
  write_vars_to_cdf(data(), fname2, extent=c(0, 1, 0, 1), attrs=list(list(key="distribution", val="gev"),
                                                                     list(key="variable", val="temperature")))

  fits <- read_fits_from_cdf(c(fname1, fname2))

  expect_named(fits, c('rainfall', 'temperature'), ignore.order=TRUE)
  expect_equal(dim(fits[['rainfall']]), c(3,3,3))
  expect_equal(dim(fits[['temperature']]), c(3,3,3))
  expect_equal(dimnames(fits[['rainfall']])[[3]], c('location', 'scale', 'shape'))

  file.remove(fname1)
  file.remove(fname2)
})

test_that('we get a helpful error message when trying to access data that does not exist', {
  for (f in c('sdfy.nc::sdf', 'sdgy.tif', 'dsaf.mon')) {
    expect_error(read_vars(f), paste0('does not exist'))
  }
})

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

  expect_equal(
    read_vars_from_cdf(fname)$data[[1]]
    ,
    data)

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

test_that('we can read a specific 2d portion of a variable from a raster file', {
  fname <- tempfile(fileext='.tif')

  data <- matrix(1:15, nrow=3, byrow=TRUE)

  rast_out <- methods::new(suppressMessages(methods::getClassDef('GDALTransientDataset', package='rgdal')),
                           driver=methods::new(methods::getClassDef('GDALDriver', package='rgdal'), 'GTiff'),
                           cols=ncol(data),
                           rows=nrow(data),
                           bands=1,
                           type='float32')

  rast_out <- rgdal::saveDataset(rast_out,
                                 fname,
                                 options=c("COMPRESS=DEFLATE"),
                                 returnNewObj=TRUE)

  rgdal::putRasterData(rast_out, t(data), band=1)
  rgdal::GDAL.close(rast_out)

  entire <- read_vars(fname)
  expect_equal(entire$data[[1]], data, check.attributes=FALSE)

  middle <- read_vars(fname, offset=c(3, 1), count=c(1, -1))
  expect_equal(middle$data[[1]], rbind(3, 8, 13))
  expect_equal(middle$extent, c(2, 3, 0, 3))

  lower_right <- read_vars(fname, offset=c(4, 2), count=c(-1, 2))
  expect_equal(lower_right$data[[1]], rbind(c(9, 10), c(14, 15)), check.attributes=FALSE)
  expect_equal(lower_right$extent, c(3, 5, 0, 2), check.attributes=FALSE)

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

  file.remove(fname)
})

test_that('read vars bails if asked to read a list of files at once', {
  fname1 <- paste0(tempfile(), '.nc')
  fname2 <- paste0(tempfile(), '.nc')

  data <- function() {
    list(
      location= matrix(runif(9), nrow=3),
      scale= matrix(runif(9), nrow=3),
      shape= matrix(runif(9), nrow=3)
    )
  }

  write_vars_to_cdf(data(), fname1, extent=c(0, 1, 0, 1))
  write_vars_to_cdf(data(), fname2, extent=c(0, 1, 0, 1))

  expect_error(read_vars(c(fname1, fname2)))

  file.remove(fname1)
  file.remove(fname2)
})
