# Copyright (c) 2019 ISciences, LLC. # All rights reserved.
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

context('Raster operations')

test_that('Reclassification produces correct values', {
  x <- rbind(
    c(1, NA,  4),
    c(0, 9, -10)
  )
  
  subs <- rbind(
    c(1,  NA),
    c(NA,  8),
    c(0,  12),
    c(-10, 8)
  )
  
  expect_error(reclassify(x, subs, FALSE))
  
  rs <- reclassify(x, subs, TRUE)
  
  expect_equal(rs, rbind(
    c(NA, 8, NA),
    c(12, NA, 8)))
})
