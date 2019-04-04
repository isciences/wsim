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

context('Reading variable names')

test_that('We get an error if the file does not exist', {
  expect_error(read_dimension_values(tempfile(fileext='.tif')))
  expect_error(read_dimension_values(tempfile(fileext='.nc')))
})

test_that('We can get a list of variable names from a netCDF', {
  fname <- tempfile(fileext='.nc')

  write_vars_to_cdf(list(data=matrix(runif(100), nrow=10),
                         data2=matrix(runif(100), nrow=10)),
                    fname,
                    extent=c(0, 1, 0, 1))

  expect_setequal(read_varnames(fname), c('data', 'data2'))

  file.remove(fname)
})
