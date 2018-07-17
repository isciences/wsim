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
require(Rcpp)

context('Basin-to-Basin Flow Accumulation')

test_basins <- function() {
  # ####################### #
  # Flow network            #
  # basin_id[basin_flow]    #
  # ####################### #
  # 1[2] <-- 2[3] <-- 3[5]  #
  # ^        ^              #
  # |        |              #
  # 5[11]    4[7]           #
  #                         #
  # 6[13]                   #
  # ####################### #
  basins <- data.frame()

  basins <- rbind(basins,
                  list(id=1, downstream=0, flow=2),
                  list(id=2, downstream=1, flow=3),
                  list(id=3, downstream=2, flow=5),
                  list(id=4, downstream=2, flow=7),
                  list(id=5, downstream=1, flow=11),
                  list(id=6, downstream=0, flow=13)
                  )
  return(basins)
}

test_that('output flows are correct', {
   basins <- test_basins()

   basins$accumulated <- accumulate(basins$id, basins$downstream, basins$flow)

   expect_equal(basins$accumulated,
               c(2+3+5+7+11,
                 3+5+7,
                 5,
                 7,
                 11,
                 13))
})

test_that('downstream values are correct', {
   basins <- test_basins()

   basins$downstream_flow <- downstream_flow(basins$id, basins$downstream, basins$flow)

   expect_equal(basins$downstream_flow,
                c(0,
                  2,
                  2+3,
                  2+3,
                  2,
                  0))

})

test_that('it errors out on input length mismatches', {
  expect_error(accumulate(1:3, 0:2, c(1, 7)),       'Expected [0-9]+ flows but got [0-9]+')
  expect_error(accumulate(1:3, 0:2, c(1, 7, 1, 7)), 'Expected [0-9]+ flows but got [0-9]+')
  expect_error(accumulate(1:3, 0:1, c(1, 7, 7)),    'Expected [0-9]+ .*IDs but got [0-9]+')
  expect_error(accumulate(1:3, 0:4, c(1, 7, 7)),    'Expected [0-9]+ .*IDs but got [0-9]+')
})

test_that('it errors when basin IDs are invalid', {
  expect_error(accumulate(1:3, 2:4, 1:3,
                          'Basin [0-9]+ references downstream basin [0-9]+, but it does not exist.'))
})
