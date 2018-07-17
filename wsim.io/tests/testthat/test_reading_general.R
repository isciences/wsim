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

context("Reading files (general)")

test_that('read vars bails if asked to read a list of files at once', {
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
  write_vars_to_cdf(data(), fname2, extent=c(0, 1, 0, 1))

  expect_error(read_vars(c(fname1, fname2)))

  file.remove(fname1)
  file.remove(fname2)
})

