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
  fname <- tempfile(fileext='.nc')
  data <- matrix(runif(4), nrow=2)
  data_2 <- matrix(runif(4), nrow=2)

  write_vars_to_cdf(list(my_data=data, my_data_2=data_2),
                    fname,
                    xmin=-40,
                    xmax=0,
                    ymin=20,
                    ymax=70,
                    attrs=list(list(var="my_data", key="station",     val="A"),
                               list(var="*",       key="reliability", val="good"),
                               list(               key="yearmon",     val="201702")))

  expect_true(file.exists(fname))

  cdf <- ncdf4::nc_open(fname)

  expect_equal(length(cdf$var), 2+1) # include CRS var
  expect_equal(cdf$var[[1]]$name, "my_data")
  expect_equal(cdf$var[[2]]$name, "my_data_2")

  expect_equal(ncdf4::ncatt_get(cdf, varid=0,           attname="yearmon")$value,     "201702")

  expect_equal(ncdf4::ncatt_get(cdf, varid="my_data",   attname="station")$value,     "A")
  expect_equal(ncdf4::ncatt_get(cdf, varid="my_data",   attname="reliability")$value, "good")

  expect_false(ncdf4::ncatt_get(cdf, varid="my_data_2", attname="station")$hasatt)
  expect_equal(ncdf4::ncatt_get(cdf, varid="my_data_2", attname="reliability")$value, "good")

  # Note that our lat-lon input matrix was written to a lon-lat matrix in the netCDF
  expect_equal(ncdf4::ncvar_get(cdf, "my_data"), t(data))

  ncdf4::nc_close(cdf)

  file.remove(fname)
})

test_that("spatial data is written in a way that is comprehensible to GDAL", {
  fname <- tempfile(fileext='.nc')

  data <- matrix(runif(18*36), nrow=18)

  write_vars_to_cdf(list(data=data),
                    filename=fname,
                    extent=c(-180, 180, -90, 90))

  suppressWarnings(info <- rgdal::GDALinfo(fname))

  expect_equal(info["rows"], 18, check.attributes=FALSE)
  expect_equal(info["columns"], 36, check.attributes=FALSE)
  expect_equal(info["ll.x"], -180, check.attributes=FALSE)
  expect_equal(info["ll.y"], -90, check.attributes=FALSE)
  expect_equal(info["res.x"], 10, check.attributes=FALSE)
  expect_equal(info["res.y"], 10, check.attributes=FALSE)

  file.remove(fname)
})

test_that("vars can be written from rasters instead of raw matrices", {
  fname <- tempfile(fileext=".nc")
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
  fname <- tempfile(fileext='.nc')

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
  fname <- tempfile(fileext='.nc')

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
  fname <- tempfile(fileext='.nc')

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

test_that("we cannot write if variable and id dimensions do not match", {
  fname <- tempfile(fileext='.nc')

  n <- 25000 # this is high, but for some reason ncdf4 generates its own
             # error for low N. For high N, it generates no error but goes
             # on to segfault.
  data <- data.frame(id=sapply(1:n, function(i) paste0(sample(LETTERS, 8), collapse='')),
                     v1=runif(n),
                     v2=runif(n),
                     stringsAsFactors=FALSE)

  expect_error(
    write_vars_to_cdf(data[-1, -1], fname, ids=data$id),
    "Variable .* has .* values but we have .*"
  )
})


test_that("numeric precision can be specified on a per-variable basis", {
  fname <- tempfile(fileext='.nc')

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

test_that("data types will be inferred if they are not specified", {
  fname <- tempfile(fileext='.nc')

  data <- list(
    double_var= runif(10),
    float_var= runif(10),
    int_var= 1:10,
    logical_var= runif(10) < 0.5,
    string_var= sapply(1:10, function(i) paste(sample(letters, 4), collapse=''))
  )

  write_vars_to_cdf(data, fname, ids=1:10, prec=list(float_var='single'))

  v <- ncdf4::nc_open(fname)
  var_prec <- lapply(v$var, function(var) var$prec)

  expect_equal(var_prec$double_var, 'double')
  expect_equal(var_prec$float_var, 'float')
  expect_equal(var_prec$int_var, 'int')
  expect_equal(var_prec$logical_var, 'byte')
  expect_equal(var_prec$string_var, 'char')


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
  fname <- tempfile(fileext='.nc')
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

test_that('numeric ids must be integers or integer-coercible', {
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

test_that('we can use text-based ids', {
  fname <- tempfile(fileext='.nc')
  data <- runif(4)
  ids <- sprintf('Station #%d', 1:length(data))

  write_vars_to_cdf(list(my_data=data),
                    fname,
                    ids=ids)

  expect_true(file.exists(fname))

  cdf <- ncdf4::nc_open(fname)

  # one variable
  expect_equal(length(cdf$var), 1)
  expect_equal(cdf$var[[1]]$name, "my_data")

  # one dimension
  expect_equal(length(cdf$var[[1]]$dim), 1)
  expect_equal(cdf$var[[1]]$dim[[1]]$name, 'id')

  # ids are correct
  expect_equal(ids, ncdf4::ncvar_get(cdf, "id"), check.attributes=FALSE)

  file.remove(fname)
})

test_that('we can write text attributes', {
  fname <- tempfile(fileext='.nc')

  ids <- 3:6
  temp <- runif(4)
  loc <- c('Upstairs', 'Downstairs', NA, 'Outside')

  write_vars_to_cdf(list(temp=temp, loc=loc),
                    fname,
                    ids=ids)

  expect_true(file.exists(fname))

  file.remove(fname)
})

test_that('text attributes are not supported for spatial data', {
  fname <- tempfile(fileext='.nc')

  temp <- matrix(runif(4), nrow=2)
  loc <- rbind(c('Upstairs', 'Downstairs'),
               c('Garage',   'Outside'))

  expect_error(
    write_vars_to_cdf(list(temp=temp, loc=loc),
                      fname,
                      extent=c(0, 0, 1, 1)),
    "only supported for non-spatial"
  )
})

test_that('we get an error when writing undefined IDs', {
  fname <- tempfile(fileext='.nc')

  expect_error(
    write_vars_to_cdf(list(data=runif(4)),
                      fname,
                      ids=c(1,2,NA,3)),
    "IDs must be defined"
  )
})

test_that('factors are converted to text when writing to netCDF', {
  fname <- tempfile(fileext='.nc')

  data <- rbind(
    data.frame(id=1, capacity=5, fuel="Hydro"),
    data.frame(id=2, capacity=7, fuel="Coal")
  )

  write_vars_to_cdf(data[, -1], fname, ids=data[, 1])

  cdf <- ncdf4::nc_open(fname)

  expect_equal(as.character(data$fuel),
               ncdf4::ncvar_get(cdf, 'fuel'),
               check.attributes=FALSE)

  file.remove(fname)
})

test_that('we get a useful error message if we forget to provide variable names', {
  expect_error(write_vars_to_cdf(list(1:8), '', ids=2:9),
               'must be .* a named list')
})

test_that('we can write multidimensional spatial data', {
  fname <- tempfile(fileext='.nc')

  data <- array(1:120, dim=c(5,8,3))
  crops <- c('maize', 'corn', 'wheat')
  quantiles <- c(25, 50, 75)

  write_vars_to_cdf(list(yield=abind::abind(data-0.1,
                                            data,
                                            data+0.1,
                                            rev.along=0)),
                         fname,
                         extent=c(-180, 180, -90, 90),
                         extra_dims=list(
                           crop=crops,
                           quantile=quantiles
                         ))

  nc <- ncdf4::nc_open(fname)
  ncdat <- ncdf4::ncvar_get(nc, 'yield')

  expect_equal(ncdat[,,which(crops=='wheat'), which(quantiles==50)],
               t(data[,,which(crops=='wheat')]))
  expect_equal(ncdat[,,which(crops=='wheat'), which(quantiles==75)],
               0.1+t(data[,,which(crops=='wheat')]))

  file.remove(fname)
})

test_that('we can write data where different variables have different numbers of dimensions', {
  fname <- tempfile(fileext='.nc')

  crops <- c('wheat', 'maize')
  stresses <- c('heat', 'cold', 'hail')

  write_vars_to_cdf(list(months_stress=array(0L, dim=c(5,8,2,3))),
                    fname,
                    extent=c(-180, 180, -90, 90),
                    extra_dims=list(
                      crop=crops,
                      stress=stresses
                    ),
                    prec='byte')

  write_vars_to_cdf(list(cumulative_stress=array(0L, dim=c(5,8,2))),
                    fname,
                    extent=c(-180, 180, -90, 90),
                    extra_dims=list(
                      crop=crops
                    ),
                    prec='double',
                    append=TRUE)

  file.remove(fname)
})

test_that('we can write multidimensional id-based data', {
  fname <- tempfile(fileext='.nc')

  # 4 regions
  # 3 crops
  # 3 quantiles
  data <- data.frame(
    id=rep(1:4, each=9),
    crop=rep.int(rep(c('corn', 'wheat', 'maize'), each=3), 4),
    quantile=rep.int(c(0.25, 0.5, 0.75), 12),
    yield=1:36,
    stringsAsFactors = FALSE
  )

  write_vars_to_cdf(data,
                    fname,
                    ids=sort(unique(data$id)),
                    extra_dims=list(
                      crop=sort(unique(data$crop)),
                      quantile=sort(unique(data$quantile))
                    ))

  cdf <- ncdf4::nc_open(fname)

  real_dims <- Filter(function(n) {
    !endsWith(n, '_nchar')
  }, names(cdf$dim))

  real_vars <- names(cdf$var)

  data_reconstructed <- cbind(
    do.call(combos,
            sapply(real_dims, function(dimname) {
              cdf$dim[[dimname]]$vals
            })

    ),
    sapply(real_vars, function(n) ncdf4::ncvar_get(cdf, varid=n))
  )

  if ('dplyr' %in% installed.packages()[, 'Package']) ({
    expect_true(dplyr::all_equal(data, data_reconstructed))
  })

  file.remove(fname)
})

test_that('We can pass an array that has dimnames instead of a named list of variables', {
  fname <- tempfile(fileext='.nc')

  dat <- array(runif(120), dim=c(5, 8, 3))

  expect_error(
    write_vars_to_cdf(dat, fname, extent=c(0,1,0,1)),
    'must be an array with dimnames, or a named list'
  )

  dimnames(dat)[[3]] <- c('location', 'scale', 'shape')

  write_vars_to_cdf(dat, fname, extent=c(0,1,0,1))

  cdf <- ncdf4::nc_open(fname)
  varnames <- sapply(cdf$var, function(v) v$name)

  expect_true(all(c('location', 'scale', 'shape') %in% varnames))

  file.remove(fname)
})
