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

context('Parsing exactextract results')

dat <- data.frame(
  HYBAS_ID=1:5,
  loss_rainfed_cassava_q75=runif(5),
  loss_rainfed_cassava_q25=runif(5),
  loss_irrigated_maize_1_q25=runif(5),
  loss_irrigated_maize_2_q25=runif(5),
  loss_irrigated_rice_1=runif(5),
  loss_rainfed_rice_1=runif(5),
  production_rainfed_rice_1=runif(5),
  production_irrigated_rice_1=runif(5),
  production_irrigated_maize_1=runif(5),
  production_irrigated_maize_2=runif(5),
  production_rainfed_cassava=runif(5)
)

test_that('column names and types are correct', {
  parsed <- parse_exactextract_results(dat)
  types <- sapply(parsed, mode)

  expect_named(parsed$production,                c('id',      'method',    'crop',      'subcrop',   'production'))
  expect_equal(sapply(parsed$production, mode),  c('numeric', 'character', 'character', 'character', 'numeric'), check.attributes=FALSE)
  
  expect_named(parsed$loss,                c('id',      'method',    'crop',      'subcrop',   'quantile', 'loss'))
  expect_equal(sapply(parsed$loss, mode),  c('numeric', 'character', 'character', 'character', 'numeric',  'numeric'), check.attributes=FALSE)
})


test_that('results can be read from a csv', {
  fname <- tempfile(fileext='.csv')

  write.csv(dat, fname, row.names=FALSE)

  expect_equal(parse_exactextract_results(dat),
               parse_exactextract_results(fname))

  file.remove(fname)
})
