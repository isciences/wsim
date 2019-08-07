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

context("netCDF attributes")

get_attribute <- function(attrs, attr_name) {
  Filter(function(attr) attr$key == attr_name, attrs)[[1]]$val
}

test_that('timestamp is constant between multiple calls', {
  first <- date_string()
  Sys.sleep(2)
  second <- date_string()

  expect_equal(first, second)
})

test_that('history entries are not duplicated', {
  first <- get_attribute(standard_netcdf_attrs(is_new=FALSE, is_spatial=FALSE), 'history')

  second <- get_attribute(standard_netcdf_attrs(is_new=FALSE, is_spatial=FALSE, existing_history=first), 'history')

  expect_equal(first, second)
})

