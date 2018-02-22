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

testdata <- Sys.getenv('WSIM_TEST_DATA')

isciences_internal <- function() {
  if (!file.exists(testdata)) {
    skip("Skipping test that requires ISciences internal resource.")
  }
}

expect_same_extent_crs <- function(r1, r2) {
  expect_equal(raster::extent(r1), raster::extent(r2))
  expect_equal(raster::crs(r1),    raster::crs(r2))
}
