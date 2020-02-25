# Copyright (c) 2020 ISciences, LLC.
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

context("PREC/L dataset")

test_that('PREC/L data can be downloaded', {
  skip_if_not(Sys.getenv('WSIM_ALL_TESTS') == 'YES')

  fname <- tempfile(fileext='.nc')

  download_precl(fname, 2002, 7, c('gauge_count', 'precipitation_rate'))

  data <- read_vars(fname)

  expect_equal(data$extent, c(-180, 180, -90, 90))
  expect_named(data$data, c('num_stations', 'Pr'))
  expect_equal(dim(prate$data[[1]]), c(360, 720))

  px_mm_day <- data$data$Pr * 24 * 3600

  # compare to pixel 540, 260 in the f77_read.f test program
  # to do so, we need to reverse the longitude wrapping and latitude flipping
  px_mm_day <- px_mm_day[360:1, c(361:720, 1:360)]
  px_sta <- data$data$num_stations[360:1, c(361:720, 1:360)]

  expect_equal(10*px_mm_day[260, 540], 18.8666878)
  expect_equal(px_sta[260, 540], 0)

  file.remove(fname)
})
