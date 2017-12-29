require(testthat)

context('Input expansion')

test_that('We can use glob expansion', {
  dirname <- tempfile('dir')
  dir.create(dirname)

  files <- c(file.path(dirname, 'saucisse'),
             file.path(dirname, 'saucisson'))

  file.create(files)

  # Basic wildcard expansion works
  expect_equal(
    expand_inputs(file.path(dirname, 'sauciss*')),
    files
  )

  # Error is thrown if no files match glob
  expect_error(
    expand_inputs(file.path(dirname, 'sauce*'))
  )

  # Unless we tell it not to check existence
  expect_equal(
    expand_inputs(file.path(dirname, 'sauce*'), check_exists=FALSE),
    file.path(dirname, 'sauce*')
  )

})

test_that("We can use date-range expansion", {
  expect_equal(
    expand_inputs('results_[201211:201303].nc', check_exists=FALSE),
    c('results_201211.nc', 'results_201212.nc', 'results_201301.nc', 'results_201302.nc', 'results_201303.nc')
  )
})

test_that("Date-range expansion can specify a timestep in months", {
  expect_equal(
    expand_inputs('results_[201203:201303:4].nc', check_exists=FALSE),
    c('results_201203.nc', 'results_201207.nc', 'results_201211.nc', 'results_201303.nc')
  )
})

test_that("Last date in range is not included when it is not a multiple of timestep", {
  expect_equal(
    expand_inputs('results_[201201:201204:2].nc', check_exists=FALSE),
    c('results_201201.nc', 'results_201203.nc')
  )
})

test_that("Multiple date ranges can be included, giving a Cartestian product", {
  expect_equal(
    expand_inputs('results_[201201:201203]_fcst[201206:201207].nc', check_exists=FALSE),
    c('results_201201_fcst201206.nc',
      'results_201201_fcst201207.nc',
      'results_201202_fcst201206.nc',
      'results_201202_fcst201207.nc',
      'results_201203_fcst201206.nc',
      'results_201203_fcst201207.nc')
  )
})

test_that("Dates can be expended in YYYYMMDD format as well as YYYYMM", {
  expect_equal(
    expand_inputs('PRECIP_[20170101:20170104].RT', check_exists=FALSE),
    c('PRECIP_20170101.RT',
      'PRECIP_20170102.RT',
      'PRECIP_20170103.RT',
      'PRECIP_20170104.RT')
  )
})

test_that("YYYY format works too", {
  expect_equal(
    expand_inputs('income_[2002:2006:2].csv', check_exists=FALSE),
    c('income_2002.csv',
      'income_2004.csv',
      'income_2006.csv')
  )
})
