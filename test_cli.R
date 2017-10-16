require(testthat)
require(wsim.io)

context("Command-line tools")

dims <- c(3, 7)
extent <- c(-40, -20, 20, 30)

for (i in 1:10) {
  vals <- array(i, dim=dims)
  fname <- paste0('/tmp/constant_', i, '.nc')
  write_vars_to_cdf(list(data=vals), fname, extent=extent)
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
  expect_equal(names(results$data), c('data_a_min',
                                      'data_a_max',
                                      'data_b_max',
                                      'data_c_min',
                                      'data_c_max'))

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