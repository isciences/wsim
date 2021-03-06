#!/usr/bin/env Rscript

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
require(sf) # to write shapefiles of test data
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

test_that("all tools return 1 on error", {
  tools <- c(
    'wsim_anom.R',
    'wsim_composite.R',
    'wsim_correct.R',
    'wsim_fit.R',
    'wsim_flow.R',
    'wsim_integrate.R',
    'wsim_lsm.R',
    'wsim_merge.R',
    'wsim_electricity_aggregate_losses.R',
    'wsim_electricity_basin_loss_factors.R',
    'wsim_ag.R',
    'wsim_ag_aggregate.R'
  )

  for (tool in tools) {
    return_code <- system2(paste0('./', tool), args=c('--garbage', '--arguments'))
    expect_equal(return_code, 1)
  }
})

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

test_that("wsim_integrate can attch arbitrary attributes to outputs", {
  input1 <- tempfile(fileext='.nc')
  input2 <- tempfile(fileext='.nc')
  output <- tempfile(fileext='.nc')

  for (f in c(input1, input2)) {
    write_vars_to_cdf(list(data=runif(10)), f, ids=14:23)
  }

  return_code <- system2('./wsim_integrate.R', args=c(
    '--stat',   'min',
    '--stat',   'max',
    '--input',  input1,
    '--input',  input2,
    '--output', output,
    '--attr',   'data_min:window_months=6',
    '--attr',   'output_type=integrated'
  ))

  expect_equal(return_code, 0)

  cdf <- ncdf4::nc_open(output)

  expect_equal(ncdf4::ncatt_get(cdf, 0)$output_type, 'integrated')
  expect_equal(ncdf4::ncatt_get(cdf, 'data_min')$window_months, '6')
  expect_null(ncdf4::ncatt_get(cdf, 'data_max')$window_months)

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

test_that("wsim_integrate appends to files instead of overwriting them", {
  # this behavior doesn't seem especially desirable, but the spinup steps that
  # build the climate norm forcing depend on it.

  output <- tempfile(fileext='.nc')

  return_code <- system2('./wsim_integrate.R', args=c(
    '--stat',  'min::data',
    '--input', '/tmp/constant_2.nc',
    '--input', '/tmp/constant_4.nc',
    '--output', output
  ))

  expect_equal(return_code, 0)
  return_code <- system2('./wsim_integrate.R', args=c(
    '--stat',  'max::data',
    '--input', '/tmp/constant_2.nc',
    '--input', '/tmp/constant_4.nc',
    '--output', output
  ))

  nc <- ncdf4::nc_open(output)
  expect_setequal(sapply(nc$var, function(v) v$name),
                  c('data_min', 'crs', 'data_max'))
  ncdf4::nc_close(nc)

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

test_that("wsim_merge fails if input datasets are not congruent", {
  input_1 <- tempfile(fileext='.nc')
  input_2 <- tempfile(fileext='.nc')
  output <- tempfile(fileext='.nc')

  data <- matrix(runif(12), nrow=3)
  extent <- c(0, 1, 0, 1)

  # Different resolution
  wsim.io::write_vars_to_cdf(list(a=data), extent=extent, filename=input_1)
  wsim.io::write_vars_to_cdf(list(b=t(data)), extent=extent, filename=input_2)

  return_code <- system2('./wsim_merge.R', args=c(
    '--input',  input_1,
    '--input',  input_2,
    '--output', output
  ))

  expect_equal(1, return_code)

  # Different extent
  wsim.io::write_vars_to_cdf(list(a=data), extent=extent,     filename=input_1)
  wsim.io::write_vars_to_cdf(list(b=data), extent=(1+extent), filename=input_2)

  return_code <- system2('./wsim_merge.R', args=c(
    '--input',  input_1,
    '--input',  input_2,
    '--output', output
  ))

  expect_equal(1, return_code)

  file.remove(input_1)
  file.remove(input_2)
})

test_that("wsim_merge works with ID-based data", {
  input_1 <- tempfile(fileext='.nc')
  input_2 <- tempfile(fileext='.nc')
  output <- tempfile(fileext='.nc')

  ids <- 5:16

  wsim.io::write_vars_to_cdf(list(a=runif(12)), ids=ids, filename=input_1)
  wsim.io::write_vars_to_cdf(list(b=runif(12)), ids=ids, filename=input_2)

  return_code <- system2('./wsim_merge.R', args=c(
    '--input',  input_1,
    '--input',  input_2,
    '--output', output
  ))

  expect_equal(0, return_code)

  # Different extent
  wsim.io::write_vars_to_cdf(list(a=runif(12)), ids=ids,     filename=input_1)
  wsim.io::write_vars_to_cdf(list(b=runif(12)), ids=(1+ids), filename=input_2)

  return_code <- system2('./wsim_merge.R', args=c(
    '--input',  input_1,
    '--input',  input_2,
    '--output', output
  ))

  expect_equal(1, return_code)

  file.remove(input_1)
  file.remove(input_2)
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

test_that("wsim_fit saves the distribution, input variable name, and arbitrary arguments as attributes", {
  output <- tempfile(fileext='.nc')

  return_code <- system2('./wsim_fit.R', args=c(
    '--distribution', 'pe3',
    '--input', '/tmp/constant_1.nc',
    '--input', '/tmp/constant_2.nc',
    '--input', '/tmp/constant_3.nc',
    '--attr',  'integration_window=6',
    '--attr',  'location:abbrev_name=loc',
    '--output', output
  ))

  expect_equal(return_code, 0)

  cdf <- ncdf4::nc_open(output)
  expect_equal('pe3', ncdf4::ncatt_get(cdf, 0, 'distribution')$value)
  expect_equal('data', ncdf4::ncatt_get(cdf, 0, 'variable')$value)

  expect_equal('6', ncdf4::ncatt_get(cdf, 0, 'integration_window')$value)
  expect_equal('loc', ncdf4::ncatt_get(cdf, 'location', 'abbrev_name')$value)

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

test_that("wsim_composite does what it's supposed to", {
  indicators <- tempfile(fileext='.nc')
  output <- tempfile(fileext='.nc')

  wsim.io::write_vars_to_cdf(
    list(surp1=rbind(c(1, 1), c(NA, 1)),
         surp2=rbind(c(2, 2), c(-2, 3)),
         def1=rbind(c(-1, 3), c(-2, -7)),
         def2=rbind(c(-2, 1), c(-1, -1))),
    indicators,
    extent=c(0, 1, 0, 1))

  return_code <- system2('./wsim_composite.R', args=c(
    '--surplus', paste0(indicators, '::surp1,surp2'),
    '--deficit', paste0(indicators, '::def1'),
    '--deficit', paste0(indicators, '::def2'),
    '--mask', paste0(indicators, '::surp1'),
    '--both_threshold', '2',
    '--clamp', '5',
    '--output', output
  ))

  expect_equal(return_code, 0)

  composite <- wsim.io::read_vars(output)

  expect_equal(composite$data$surplus, rbind(c(2, 2), c(NA, 3)), check.attributes=FALSE)
  expect_equal(composite$data$surplus_cause, rbind(c(2, 2), c(NA, 2)), check.attributes=FALSE)

  expect_equal(composite$data$deficit, rbind(c(-2, 1), c(NA, -5)), check.attributes=FALSE)
  expect_equal(composite$data$deficit_cause, rbind(c(2, 2), c(NA, 1)), check.attributes=FALSE)

  expect_equal(composite$data$both, rbind(c(0, 0), c(NA, 5)), check.attributes=FALSE)

  file.remove(indicators)
  file.remove(output)
})

test_that('wsim_flow accumulates flow based on downstream id linkage (basin-to-basin)', {
  flows <- tempfile(fileext='.nc')
  downstream <- tempfile(fileext ='.nc')
  accumulated <- tempfile(fileext='.nc')

  wsim.io::write_vars_to_cdf(
    vars=list(RO=c(1, 3, 5, 7)),
    filename=flows,
    ids=1:4
  )

  wsim.io::write_vars_to_cdf(
    vars=list(downstream=c(0, 1, 1, 2)),
    filename=downstream,
    ids=1:4
  )

  return_code <- system2('./wsim_flow.R', args=c(
    '--input',   flows,
    '--flowdir', downstream,
    '--varname', 'Bt_RO',
    '--out',     accumulated
  ))

  expect_equal(return_code, 0)

  output <- wsim.io::read_vars(accumulated)

  expect_equal(output$data$Bt_RO, c(16, 10, 5, 7), check.attributes=FALSE)

  # use same inputs but get downstream flow
  return_code <- system2('./wsim_flow.R', args=c(
    '--input',   flows,
    '--flowdir', downstream,
    '--varname', 'Bt_RO',
    '--out',     accumulated,
    '--invert'
  ))

  expect_equal(return_code, 0)

  output <- wsim.io::read_vars(accumulated)

  expect_equal(output$data$Bt_RO, c(0, 1, 1, 4), check.attributes=FALSE)

  file.remove(flows)
  file.remove(downstream)
  file.remove(accumulated)
})

test_that('wsim_flow accumulates flow based on flow direction grid (pixel-based)', {
  flows <- tempfile(fileext='.nc')
  flowdirs <- tempfile(fileext ='.nc')
  accumulated <- tempfile(fileext='.nc')

  wsim.io::write_vars_to_cdf(
    vars=list(RO=rbind(c(1, 3), c(5, 7))),
    filename=flows,
    extent=c(0, 1, 0, 1)
  )

  wsim.io::write_vars_to_cdf(
    vars=list(flowdirs=rbind(c(NA, 16), c(64, 64))),
    filename=flowdirs,
    extent=c(0, 1, 0, 1)
  )

  return_code <- system2('./wsim_flow.R', args=c(
    '--input',   flows,
    '--flowdir', flowdirs,
    '--varname', 'Bt_RO',
    '--out',     accumulated
  ))

  expect_equal(return_code, 0)

  output <- wsim.io::read_vars(accumulated)

  expect_equal(output$data$Bt_RO, rbind(c(16, 10), c(5, 7)), check.attributes=FALSE)

  file.remove(flows)
  file.remove(flowdirs)
  file.remove(accumulated)
})
