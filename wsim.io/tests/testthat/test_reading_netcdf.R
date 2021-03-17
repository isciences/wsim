# Copyright (c) 2018-2020 ISciences, LLC.
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
  data  <- matrix(runif(4), nrow=2)

  # Case 1: extra_dim has single value for all cells
  write_vars_to_cdf(list(my_data=data),
                    fname,
                    xmin=-40,
                    xmax=0,
                    ymin=20,
                    ymax=70,
                    extra_dims=list(time = 00000),
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

test_that("we can read specified non-constant extra_dims", {
  fname <- tempfile(fileext='.nc')
  data  <- array(1:8, dim=c(2,2,2))

  write_vars_to_cdf(list(my_data=data),
                    fname,
                    xmin=-40,
                    xmax=0,
                    ymin=20,
                    ymax=70,
                    extra_dims=list(time=c(1, 2)),
                    attrs=list(list(var="my_data", key="station", val="A"),
                               list(key="yearmon", val="201702")))

  v <- read_vars_from_cdf(fname, extra_dims=list(time=2))

  # Make sure it picked the second slice:
  expect_equal(v$data$my_data, matrix(5:8, nrow=2, ncol=2), check.attributes=FALSE)

  file.remove(fname)
})

test_that("unspecified, non-constant extra_dims can't be read in", {
  fname <- tempfile(fileext='.nc')
  data  <- array(1:8, dim=c(2,2,2))

  write_vars_to_cdf(list(my_data=data),
                    fname,
                    xmin=-40,
                    xmax=0,
                    ymin=20,
                    ymax=70,
                    extra_dims=list(time=c(1, 2)),
                    attrs=list(list(var="my_data", key="station", val="A"),
                               list(key="yearmon", val="201702")))

  expect_error(read_vars_from_cdf(fname))
  file.remove(fname)
})

test_that("lat/lon don't get counted as extra dims when constant across cells", {
  fname <- tempfile(fileext='.nc')
  data  <- matrix(runif(4), nrow=1, ncol=4)

  write_vars_to_cdf(list(my_data=data),
                    fname,
                    xmin=-40,
                    xmax=70,
                    ymin=20,
                    ymax=20,
                    attrs=list(list(var="my_data", key="station", val="A"),
                               list(key="yearmon", val="201702")))

  v <- read_vars_from_cdf(fname)

  # Grid extent is returned as xmin, xmax, ymin, ymax
  expect_equal(v$extent, c(-40, 70, 20, 20))

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

test_that("we can read attributes and variables from a non-spatial netCDF file into a data frame", {
  fname <- tempfile(fileext='.nc')

  var_a <- runif(4)
  var_b <- runif(4)
  var_c <- c('A', 'B', 'C', 'XX')

  write_vars_to_cdf(list(var_a=var_a, var_b=var_b, var_c=var_c),
                    fname,
                    ids=2:5,
                    attrs=list(list(var="var_a", key="station", val="A"),
                               list(var="var_b", key="station", val="B"),
                               list(key="yearmon", val="201702")))

  v <- read_vars(fname, as.data.frame=TRUE)

  expect_equal(names(v), c('id', 'var_a', 'var_b', 'var_c'), check.attributes=FALSE)
  expect_equal(v$id, 2:5, check.attributes=FALSE)
  expect_equal(v$var_a, var_a, check.attributes=FALSE)
  expect_equal(v$var_b, var_b, check.attributes=FALSE)
  expect_equal(v$var_c, var_c, check.attributes=FALSE)

  # No extent for non-spatial data
  expect_null(attr(v, 'extent'))

  # IDs not copied in as an attribute either
  expect_null(attr(v, 'ids'))

  # Global attributes preserved
  expect_equal(attr(v, 'yearmon'), '201702')

  # Variable attributes are accessible as attrs of their columns
  expect_equal(attr(v$var_a, 'station'), 'A')
  expect_equal(attr(v$var_b, 'station'), 'B')

  file.remove(fname)
})

test_that("we can read a spatial netCDF file into a data frame", {
  fname <- tempfile(fileext='.nc')
  data <- matrix(runif(4), nrow=2)

  write_vars_to_cdf(list(my_data=data),
                    fname,
                    xmin=-40,
                    xmax=0,
                    ymin=20,
                    ymax=70,
                    attrs=list(list(var="my_data", key="station", val="a"),
                               list(key="yearmon", val="201702")))

  v <- read_vars(fname, as.data.frame=TRUE)

  expect_equal(v, rbind(
    data.frame(lon=-30, lat=57.5, my_data=data[1,1]),
    data.frame(lon=-30, lat=32.5, my_data=data[2,1]),
    data.frame(lon=-10, lat=57.5, my_data=data[1,2]),
    data.frame(lon=-10, lat=32.5, my_data=data[2,2])
  ), check.attributes=FALSE)

  file.remove(fname)
})

test_that("we can read text IDs", {
  fname <- tempfile(fileext='.nc')
  data <- runif(10)

  ids <- sapply(1:length(data), function(.) paste0(sample(LETTERS, 1 + 10*runif(1)), collapse=""))

  write_vars_to_cdf(list(data=data), fname, ids=ids)

  d <- read_vars_from_cdf(fname)

  expect_equal(ids, d$ids, check.attributes=FALSE)
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

  write_vars_to_cdf(data, fname, extent=extent, attrs=list(
    list(var=NULL,       key='globalatt',    val=12345),
    list(var='location', key='units',        val='kilocalories'),
    list(var='location', key='units_abbrev', val='kcal')
  ))

  cube <- read_vars_to_cube(fname,
                            attrs_to_read=c('globalatt',      # global attribute specified as such
                                            'location:units', # attribute of named regular variable
                                            'units_abbrev',   # attribute of unnamed regular variable
                                            'crs:grid_mapping_name',  # attribute of named no-data variable
                                            'location:doesnotexist')) # non-existant attribute

  expect_equal(attr(cube, "extent"), extent)
  expect_equal(cube[,,"location"], data$location)
  expect_equal(cube[,,"scale"], data$scale)
  expect_equal(cube[,,"shape"], data$shape)

  expect_equal(dimnames(cube)[[3]], c('location', 'scale', 'shape'))

  expect_equal(attr(cube, 'globalatt'), 12345)
  expect_equal(attr(cube, 'units'), 'kilocalories')
  expect_equal(attr(cube, 'units_abbrev'), 'kcal')
  expect_equal(attr(cube, 'grid_mapping_name'), 'latitude_longitude')

  expect_null(attr(cube, 'doesnotexist'))

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
  expect_error(read_fits_from_cdf(fname1),
               'Unknown variable')

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

test_that('we can read sorted observations as a fit', {
  fname <- tempfile(fileext = '.nc')

  d <- c(360, 720, 60)
  arr <- array(runif(prod(d)), dim=d)

  extent <- c(-180, 180, -90, 90)

  write_vars_to_cdf(list(ordered_values=arr),
                    fname,
                    extent = extent,
                    extra_dims = list(n=seq_len(dim(arr)[3])),
                    attrs = list(
                      list(key = 'variable', val = 'Pr'),
                      list(key = 'units', val = 'kg/m^2/s'),
                      list(key = 'distribution', val = 'nonparametric')))

  fits <- read_fits_from_cdf(fname)

  expect_named(fits, 'Pr')

  expect_equal(attr(fits$Pr, 'extent'), extent, check.attributes=FALSE)
  expect_named(attr(fits$Pr, 'extent'), c('xmin', 'xmax', 'ymin', 'ymax'))

  expect_equal(attr(fits$Pr, 'units'), 'kg/m^2/s')
  expect_equal(attr(fits$Pr, 'distribution'), 'nonparametric')

  file.remove(fname)
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

test_that("we can read multidimensional tabular data", {
  fname <- tempfile(fileext='.nc')

  data <- data.frame(
    id=rep(1:4, each=8, times=1),
    crop=rep(c(13,21), each=4, times=2),
    plot=rep(c(15,19,7,3), each=1, times=4),
    yield=sqrt(1:32),
    fertilizer=(1:32)*0.1,
    stringsAsFactors=FALSE
  )

  id_dim   <- ncdf4::ncdim_def('id',   units='', vals=1:4,          create_dimvar=TRUE)
  crop_dim <- ncdf4::ncdim_def('crop', units='', vals=c(13,21),     create_dimvar=TRUE)
  plot_dim <- ncdf4::ncdim_def('plot', units='', vals=c(15,19,7,3), create_dimvar=TRUE)

  yield_var      <- ncdf4::ncvar_def('yield',      units='kg', dim=list(plot_dim, crop_dim, id_dim), prec='double')
  fertilizer_var <- ncdf4::ncvar_def('fertilizer', units='kg', dim=list(plot_dim, crop_dim, id_dim), prec='double')

  cdf <- ncdf4::nc_create(fname, vars=list(yield_var, fertilizer_var))
  ncdf4::ncvar_put(cdf, yield_var, data$yield)
  ncdf4::ncvar_put(cdf, fertilizer_var, data$fertilizer)
  ncdf4::nc_close(cdf)

  data2 <- read_vars(fname, as.data.frame=TRUE)

  data2 <- data2[names(data)]

  expect_equal(data[with(data, order(id, crop, plot)), ],
               data2[with(data2, order(id, crop, plot)), ], check.attributes=FALSE)

  file.remove(fname)
})

test_that("multidimensional tabular round-trip is successful when extra_dims specified out-of-order", {
  fname <- tempfile(fileext='.nc')

  data <- data.frame(
   id=rep(24:37, each=3),
   crop=rep(c('maize', 'sugarcane', 'salsify'), times=14),
   stringsAsFactors=FALSE
  )
  data$yield_2018 <- runif(nrow(data))
  data$yield_2017 <- runif(nrow(data))

  write_vars_to_cdf(data, fname, ids=24:37, extra_dims=list(crop=c('maize', 'sugarcane', 'salsify')))

  data2 <- read_vars_from_cdf(fname, as.data.frame=TRUE)

  data <- data[with(data, order(id, crop)), ]
  data2 <- data2[with(data2, order(id, crop)), ]

  expect_equal(data, data2, check.attributes=FALSE)

  file.remove(fname)
})

test_that("datasets from 0-360 are wrapped to -180 to 180", {
  fname <- tempfile(fileext='.nc')

  data <- matrix(1:(36*18), nrow=18, byrow=TRUE)

  write_vars_to_cdf(list(val=data),
                    fname,
                    extent=c(0, 360, -90, 90))

  data_in <- read_vars_from_cdf(fname)

  expect_equal(data_in$extent, c(-180, 180, -90, 90))

  expect_equal(data, cbind(data_in$data[[1]][, -1:-18],
                           data_in$data[[1]][,  1:18]))

  file.remove(fname)
})

test_that("ERA5 0.25-degree dataset is correctly wrapped on read", {
  fname <- tempfile(fileext = '.nc')

  nrow <- 721
  ncol <- 1440

  era5 <- raster::raster(matrix(1:(nrow*ncol), nrow=nrow),
                         xmn = -0.125,
                         xmx = 359.875,
                         ymn = -90.125,
                         ymx = 90.125)
  raster::crs(era5) <- '+proj=longlat'

  suppressWarnings({
    raster::writeRaster(era5, fname)
  })

  era5_in <- read_vars_from_cdf(fname)
  era5_inr <- raster::raster(era5_in$data[[1]],
                             xmn = era5_in$extent[1],
                             xmx = era5_in$extent[2],
                             ymn = era5_in$extent[3],
                             ymx = era5_in$extent[4])

  expect_equal(
    raster::extract(era5, cbind(30, 44)),
    raster::extract(era5_inr, cbind(30, 44))
  )
})
