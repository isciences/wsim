# Copyright (c) 2019 ISciences, LLC.
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

context('Reading dimension values')

test_that('We get an empty list with a non-netCDF file', {
  fname <- tempfile(fileext='.tif')
  write('xox', fname)

  expect_equal(list(),
               read_dimension_values(fname))

  file.remove(fname)
})

test_that('We get an error if file file does not exist', {
  expect_error(read_dimension_values(tempfile(fileext='.tif')))
  expect_error(read_dimension_values(tempfile(fileext='.nc')))
})

test_that('We get a list with dimension names and values', {
  fname <- tempfile(fileext='.nc')

  dat <- matrix(runif(100), nrow=10)
  write_vars_to_cdf(list(level=dat),
                    fname,
                    extent=c(0, 1, 0, 1),
                    extra_dims=list(crop=c('peanuts', 'cashews'),
                                    stress=c('surplus', 'deficit')),
                    write_slice=list(crop='cashews', stress='deficit'))

  dims <- read_dimension_values(fname)

  expect_setequal(names(dims), c('lat', 'lon', 'crop', 'stress'))
  expect_equal(dims$crop, c('peanuts', 'cashews'), check.attributes=FALSE)
  expect_equal(dims$stress, c('surplus', 'deficit'), check.attributes=FALSE)

  some_dims <- read_dimension_values(fname, exclude.dims=c('lon', 'stress'))
  expect_setequal(names(some_dims), c('lat', 'crop'))

  file.remove(fname)
})
