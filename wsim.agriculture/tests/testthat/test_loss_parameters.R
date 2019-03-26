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

context('Reading loss parameters')

test_that('Error raised if expected parameter missing', {
  fname <- tempfile(fileext='.csv')
  
  fileConn <- file(fname, 'w')
  writeLines(c('param,value','bad_param,5'), fileConn)
  close(fileConn)
  
  expect_error(
    read_loss_parameters(fname),
    'Parameter .* not found'
  )
  
  file.remove(fname)
})

test_that('Error raised if file does not exists', {
  expect_error(
    read_loss_parameters(tempfile(fileext='.csv')),
    'cannot open'
  )
})

test_that('Error raised if header incorrect', {
  fname <- tempfile(fileext='.csv')
  
  fileConn <- file(fname, 'w')
  writeLines(c('value, param'), fileConn)
  close(fileConn)
  
  expect_error(
    read_loss_parameters(fname),
    'Parameter .* not found'
  )
  
  file.remove(fname)
})

test_that('Types read correctly', {
  fname <- tempfile(fileext='.csv')
  
  fileConn <- file(fname, 'w')
  writeLines(
    c('param,value',
      'mean_loss_fit_a,2.34e-3',
      'mean_loss_fit_b,2.11e-6',
      'loss_initial,12',
      'loss_total,80',
      'loss_power,2'), fileConn)
  close(fileConn)
  
  params <- read_loss_parameters(fname)
  expect_true(all(sapply(params, is.numeric)))
  
  file.remove(fname)
})