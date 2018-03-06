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

context("Command-line tools")

dims <- c(3, 7)
extent <- c(-40, -20, 20, 30)

for (i in 1:10) {
  vals <- array(i, dim=dims)
  fname <- paste0('/tmp/constant_', i, '.nc')
  write_vars_to_cdf(list(data=vals),
                    fname,
                    extent=extent,
                    attrs=list(
                      list(key=paste0("global_", i), val=paste0("global_value_", i)),
                      list(var="data", key="data_attr", val=i)
                    )
  )
}

write_vars_to_cdf(list(
  data_a= array(1, dim=dims),
  data_b= array(2, dim=dims),
  data_c= array(3, dim=dims)),
  '/tmp/constant_13.nc',
  extent=extent
)

test_that("wsim_integrate can process a fixed set of files", {
  output <- paste0(tempfile(), '.nc')

  return_code <- system2('./wsim_integrate.R', args=c(
    '--stat',   'min',
    '--stat',   'max',
    '--stat',   'ave',
    '--input',  '/tmp/constant_1.nc',
    '--input',  '/tmp/constant_2.nc',
    '--input',  '/tmp/constant_3.nc',
    '--input',  '/tmp/constant_4.nc',
    '--input',  '/tmp/constant_5.nc',
    '--output', output
  ))

  expect_equal(return_code, 0)

  results <- read_vars_from_cdf(output)

  expect_equal(results$extent, extent)
  expect_equal(names(results$data), c('data_min', 'data_max', 'data_ave'))
  expect_equal(results$data$data_min[1, 1], 1)
  expect_equal(results$data$data_ave[1, 1], 3)
  expect_equal(results$data$data_max[1, 1], 5)

  file.remove(output)
})

test_that("wsim_integrate can process variables that have different names in each input", {
  output <- paste0(tempfile(), '.nc')

  return_code <- system2('./wsim_integrate.R', args=c(
    '--stat',   'min',
    '--stat',   'ave',
    '--stat',   'max',
    '--input',  '/tmp/constant_1.nc',                     # value=1
    '--input',  '"/tmp/constant_13.nc::data_c->data"',    # value=3
    '--input',  '"/tmp/constant_2.nc::data@[x+2]->data"', # value=4
    '--output', output
  ))

  expect_equal(return_code, 0)

  results <- read_vars_from_cdf(output)
  expect_equal(results$data$data_min[1, 1], 1, tolerance=1e-6)
  expect_equal(results$data$data_ave[1, 1], mean(c(1,3,4)), tolerance=1e-6)
  expect_equal(results$data$data_max[1, 1], 4, tolerance=1e-6)

  file.remove(output)
})

test_that("wsim_integrate passes attributes through from its inputs to its outputs", {
  input1 <- paste0(tempfile(), '.nc')
  input2 <- paste0(tempfile(), '.nc')
  output <- paste0(tempfile(), '.nc')

  write_vars_to_cdf(list(data=array(1, dim=dims)), input1, extent=extent, attrs=list(
    list(key="my_global", val=3),
    list(var="data", key="long_name", val="Cosmic energy"),
    list(var="data", key="source",   val="unknown")
  ))

  write_vars_to_cdf(list(data=array(1, dim=dims)), input2, extent=extent, attrs=list(
    list(key="my_global2", val=4),
    list(var="data", key="units", val="caloric quantons")
  ))

  return_code <- system2('./wsim_integrate.R', args=c(
    '--stat',   'min',
    '--stat',   'max',
    '--input',  input1,
    '--input',  input2,
    '--output', output
  ))

  expect_equal(return_code, 0)

  cdf <- ncdf4::nc_open(output)

  # Global attributes are dropped
  expect_null(ncdf4::ncatt_get(cdf, 0)$my_global)
  expect_null(ncdf4::ncatt_get(cdf, 0)$my_global2)

  # Variable attributes are passed from the first input but
  # dropped from subsequent inputs.
  expect_null(ncdf4::ncatt_get(cdf, "data_min")$units)
  expect_equal(ncdf4::ncatt_get(cdf, "data_min")$source, "unknown")

  # Special variable variables (e.g., long_name) are manipulated according
  # to the computed statistic
  expect_equal(ncdf4::ncatt_get(cdf, "data_max")$long_name, "max of Cosmic energy")

  ncdf4::nc_close(cdf)

  file.remove(input1)
  file.remove(input2)
  file.remove(output)
})

test_that("wsim_integrate can process a rolling window of files", {
  outputs <- replicate(3, paste0(tempfile(), '.nc'))

  return_code <- system2('./wsim_integrate.R', args=c(
    '--stat',   'min',
    '--stat',   'max',
    '--stat',   'ave',
    '--input',  '/tmp/constant_1.nc',
    '--input',  '/tmp/constant_2.nc',
    '--input',  '/tmp/constant_3.nc',
    '--input',  '/tmp/constant_4.nc',
    '--input',  '/tmp/constant_5.nc',
    '--window', 3,
    '--output', outputs[1],
    '--output', outputs[2],
    '--output', outputs[3]
  ))

  expect_equal(return_code, 0)

  for (i in 1:3) {
    results <- read_vars_from_cdf(outputs[i])

    expect_equal(results$extent, extent)
    expect_equal(names(results$data), c('data_min', 'data_max', 'data_ave'))
    expect_equal(results$data$data_min[1, 1], i)
    expect_equal(results$data$data_ave[1, 1], 1 + i)
    expect_equal(results$data$data_max[1, 1], 2 + i)
  }

  sapply(outputs, file.remove)
})

test_that("wsim_integrate errors out if enough outputs aren't provided for specified window size", {
  return_code <- system2("./wsim_integrate.R", args=c(
    '--stat',   'ave',
    '--input',  '/tmp/constant_1.nc',
    '--input',  '/tmp/constant_2.nc',
    '--input',  '/tmp/constant_3.nc',
    '--input',  '/tmp/constant_4.nc',
    '--input',  '/tmp/constant_5.nc',
    '--window', 3,
    '--output', 'singlefile.nc'
  ))

  expect_equal(return_code, 1)
})

test_that("wsim_integrate errors out if multiple outputs are provided without specifying a window size", {
  return_code <- system2("./wsim_integrate.R", args=c(
    '--stat',   'ave',
    '--input',  '/tmp/constant_1.nc',
    '--input',  '/tmp/constant_2.nc',
    '--input',  '/tmp/constant_3.nc',
    '--input',  '/tmp/constant_4.nc',
    '--input',  '/tmp/constant_5.nc',
    '--output', 'file1.nc',
    '--output', 'file2.nc'
  ))

  expect_equal(return_code, 1)
})

test_that("wsim_integrate can apply stats to specific variables", {
  output <- paste0(tempfile(), '.nc')

  return_code <- system2('./wsim_integrate.R', args=c(
    '--stat',   'min::data_a,data_c',
    '--stat',   'max',
    '--input',  '/tmp/constant_13.nc',
    '--output', output
  ))

  expect_equal(return_code, 0)

  results <- read_vars_from_cdf(output)

  expect_equal(results$extent, extent)
  expect_equal(sort(names(results$data)),
               sort(
                 c('data_a_min',
                   'data_a_max',
                   'data_b_max',
                   'data_c_min',
                   'data_c_max')))

  file.remove(output)
})

test_that("wsim_merge can merge datasets without attaching attributes", {
  output <- paste0(tempfile(), '.nc')

  return_code <- system2('./wsim_merge.R', args=c(
    '--input',  '"/tmp/constant_1.nc::data->data_a"',
    '--input',  '"/tmp/constant_2.nc::data->data_b"',
    '--output', output
  ))

  expect_equal(return_code, 0)

  results <- read_vars_from_cdf(output)

  expect_equal(results$extent, extent)
  expect_equal(names(results$data), c('data_a', 'data_b'))

  file.remove(output)
})

test_that("wsim_merge can merge datasets and attach attributes", {
  output <- paste0(tempfile(), '.nc')

  return_code <- system2('./wsim_merge.R', args=c(
    '--input',  '/tmp/constant_13.nc::data_a,data_c',
    '--input',  '"/tmp/constant_4.nc::data->data_d"',
    '--output', output,
    '--attr',   "myglobalattr=14",
    '--attr',   "data_d:myvarattr=22"
  ))

  expect_equal(return_code, 0)

  results <- read_vars_from_cdf(output)

  expect_equal(results$extent, extent)
  expect_equal(names(results$data), c('data_a', 'data_c', 'data_d'))
  expect_equal(results$attrs$myglobalattr, "14")
  expect_equal(attr(results$data$data_d, 'myvarattr'), "22")

  file.remove(output)
})

test_that("wsim_merge can copy attributes from an input dataset", {
  output <- paste0(tempfile(), '.nc')

  return_code <- system2('./wsim_merge.R', args=c(
    '--input',  '"/tmp/constant_3.nc::data->data_a"',
    '--input',  '"/tmp/constant_4.nc::data->data_b"',
    '--output', output,
    '--attr',   "data_a:data_attr",
    '--attr',   "data_b:data_attr"
  ))

  expect_equal(return_code, 0)
  #
  results <- read_vars_from_cdf(output)

  expect_equal(attr(results$data$data_a, 'data_attr'), 3)
  expect_equal(attr(results$data$data_b, 'data_attr'), 4)

  file.remove(output)
})

test_that("wsim_integrate doesn't propagage nonstandard _FillValue values", {
  input <- paste0(tempfile(), '.nc')
  output <- paste0(tempfile(), '.nc')

  latdim <- ncdf4::ncdim_def("lat", units="degrees_north", vals=as.double(1:2), longname="Latitude", create_dimvar=TRUE)
  londim <- ncdf4::ncdim_def("lon", units="degrees_east", vals=as.double(1:2), longname="Longitude", create_dimvar=TRUE)

  data_var <- ncdf4::ncvar_def(name="data",
                               units="none",
                               dim=list(londim, latdim),
                               missval= -8675309, # non-standard
                               prec="double",
                               compression=1)

  cdf <- ncdf4::nc_create(input, list(data_var))
  ncdf4::ncvar_put(cdf, data_var, matrix(c(1, NA, 3, NA), nrow=2))
  ncdf4::nc_close(cdf)

  return_code <- system2('./wsim_integrate.R', args=c(
    '--input',  input,
    '--input',  input,
    '--stat',   "sum",
    '--output', output
  ))

  expect_equal(return_code, 0)

  results <- wsim.io::read_vars_from_cdf(output)

  expect_equal(attr(results$data[[1]], '_FillValue'),   -3.4028234663852886e+38)
  #expect_equal(attr(results$data[[1]], 'missing_data'), -3.4028234663852886e+38)

  file.remove(input)
  file.remove(output)
})

test_that("wsim_fit errors out if input variables have different names", {
  output <- tempfile()

  return_code <- system2('./wsim_fit.R', args=c(
    '--distribution', 'gev',
    '--input', '"/tmp/constant_1.nc::data->data_q"',
    '--input', '"/tmp/constant_2.nc::data->data_q"',
    '--input', '"/tmp/constant_3.nc::data->data_z"',
    '--output', output
  ))

  expect_equal(return_code, 1)
})

test_that("wsim_fit saves the distribution and input variable name as attributes", {
  output <- tempfile()

  return_code <- system2('./wsim_fit.R', args=c(
    '--distribution', 'pe3',
    '--input', '/tmp/constant_1.nc',
    '--input', '/tmp/constant_2.nc',
    '--input', '/tmp/constant_3.nc',
    '--output', output
  ))

  expect_equal(return_code, 0)

  cdf <- ncdf4::nc_open(output)
  expect_equal('pe3', ncdf4::ncatt_get(cdf, 0, 'distribution')$value)
  expect_equal('data', ncdf4::ncatt_get(cdf, 0, 'variable')$value)

  ncdf4::nc_close(cdf)

  file.remove(output)
})

test_that("wsim_anom errors out if name of fit variable doesn't match observations", {
  fitfile <- paste0(tempfile(), '.nc')
  sa_file <- paste0(tempfile(), '.nc')

  return_code <- system2('./wsim_fit.R', args=c(
    '--distribution', 'gev',
    '--input', '"/tmp/constant_1.nc::data->data_q"',
    '--input', '"/tmp/constant_2.nc::data->data_q"',
    '--input', '"/tmp/constant_3.nc::data->data_q"',
    '--output', fitfile
  ))

  expect_equal(return_code, 0)

  return_code <- system2('./wsim_anom.R', args=c(
    '--fits', fitfile,
    '--obs', '"/tmp/constant_2.nc::data->data_q"',
    '--sa', sa_file
  ))

  expect_equal(return_code, 0)

  return_code <- system2('./wsim_anom.R', args=c(
    '--fits', fitfile,
    '--obs', '"/tmp/constant_2.nc::data->data_z"',
    '--sa', sa_file
  ))

  expect_equal(return_code, 1)

  file.remove(fitfile)
  file.remove(sa_file)
})
