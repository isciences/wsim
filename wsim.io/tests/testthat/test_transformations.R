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

context("Variable transformations")

write_matrix <- function(mat, fname) {
  write_vars_to_cdf(list(data=mat), fname, extent=c(0,1,0,1))
}

read_matrix <- function(fname, transforms) {
  read_vars_from_cdf(make_vardef(fname,
                                 list(make_var(var_in="data", transforms=transforms))))$data[[1]]
}

test_that("We can fill NODATA values with zero", {
  fname <- tempfile()

  data <- rbind(
    c(0,  1),
    c(NA, 3)
  )

  write_matrix(data, fname)

  transformed <- read_matrix(fname, c('fill0'))

  expect_equal(transformed, ifelse(is.na(data), 0, data), check.attributes=FALSE)

  file.remove(fname)
})

test_that("We can negate values", {
  fname <- tempfile()

  data <- rbind(
    c(0,  1 ),
    c(NA, -3)
  )

  write_matrix(data, fname)

  transformed <- read_matrix(fname, c('fill0', 'negate'))

  expect_equal(transformed, ifelse(is.na(data), 0, -data), check.attributes=FALSE)

  file.remove(fname)
})

test_that("We can evaluate an arbitrary R expression", {
  fname <- tempfile()

  data <- rbind(
    c(0,  1),
    c(NA, 3)
  )

  write_matrix(data, fname)

  transformed <- read_matrix(fname, c('[sqrt(x)+1]'))

  expect_equal(transformed, sqrt(data) + 1, check.attributes=FALSE)

  file.remove(fname)
})
