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

require(testthat)

context("Writing netCDF files (subsets)")

test_that('we can write a subset of multidimensional spatial data', {
  fname <- tempfile(fileext='.nc')

  data <- array(1:160, dim=c(5, 8, 4))
  crops <- c('maize', 'corn', 'wheat', 'cotton')
  stress <- c('surplus', 'deficit', 'insects')

  # initialize dimensions by writing zeros
  write_vars_to_cdf(list(yield=array(0, dim=c(5,8,4,3))),
                         fname,
                         extent=c(-180, 180, -90, 90),
                         extra_dims=list(
                           crop=crops,
                           stress=stress
                         ),
                         prec='double')

  # write a subset
  corn_deficit_yield <- array(runif(40), dim=c(5, 8))
  write_vars_to_cdf(list(yield=corn_deficit_yield),
                    fname,
                    extent=c(-180, 180, -90, 90),
                    extra_dims=list(
                      crop='corn',
                      stress='deficit'
                    ),
                    append=TRUE)

  retrieved <- read_vars_from_cdf(fname, extra_dims=list(crop='corn', stress='deficit'))
  expect_equal(retrieved$data$yield, corn_deficit_yield, check.attributes=FALSE)

  file.remove(fname)
})

test_that('we get an error if we try to partially write an extra dimension with an out-of-dimension value', {
  fname <- tempfile(fileext='.nc')

  data <- array(1:160, dim=c(5, 8, 4))
  crops <- c('maize', 'corn', 'wheat', 'cotton')
  stress <- c('surplus', 'deficit', 'insects')

  # initialize dimensions by writing zeros
  write_vars_to_cdf(list(yield=array(0, dim=c(5,8,4,3))),
                         fname,
                         extent=c(-180, 180, -90, 90),
                         extra_dims=list(
                           crop=crops,
                           stress=stress
                         ),
                         prec='double')

  # write a subset
  rye_deficit_yield <- array(runif(40), dim=c(5, 8))
  expect_error(
    write_vars_to_cdf(list(yield=rye_deficit_yield),
                      fname,
                      extent=c(-180, 180, -90, 90),
                      extra_dims=list(
                        crop='rye',
                        stress='deficit'
                      ),
                      append=TRUE),
    'Invalid value .* for dimension'
  )

  file.remove(fname)
})
