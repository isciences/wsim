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

test_that("It fails on invalid dates", {
  expect_error(
    expand_inputs('cookies_[200204:20120412].txt', check_exists=FALSE) # someone forgot the second colon
  )
})

test_that("It fails if the stop date is before the start date", {
  expect_error(
    expand_inputs('cookies_[20171231:20171201].txt', check_exists=FALSE) # can't go backwards
  )
})

test_that("It gives a reasonable error message if the format is invalid", {
  expect_error(
    expand_inputs('cookies_19[20:28].nc', check_exists=FALSE),
    "Can only expand date ranges in .* format"
  )
})
