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
  loss_current_year_rainfed_cassava_q75=runif(5),
  loss_current_year_rainfed_cassava_q25=runif(5),
  loss_current_year_irrigated_maize_1_q25=runif(5),
  loss_current_year_irrigated_maize_2_q25=runif(5),
  loss_next_year_irrigated_rice_1=runif(5),
  loss_next_year_rainfed_rice_1=runif(5),
  production_rainfed_rice_1=runif(5),
  production_irrigated_rice_1=runif(5),
  production_irrigated_maize_1=runif(5),
  production_irrigated_maize_2=runif(5),
  production_rainfed_cassava=runif(5)
)

varnames <- c('production', 'loss_current_year', 'loss_next_year')

test_that('column names and types are correct', {
  parsed <- parse_exactextract_results(dat, varnames)
  types <- sapply(parsed, mode)
  
  for (varname in varnames) {
    expect_named(parsed[[varname]],               c('id',      'method',    'crop',      'subcrop',   'quantile', varname))
    expect_equal(sapply(parsed[[varname]], mode), c('numeric', 'character', 'character', 'character', 'numeric',  'numeric'), check.attributes=FALSE)
  }
})


test_that('results can be read from a csv', {
  fname <- tempfile(fileext='.csv')

  write.csv(dat, fname, row.names=FALSE)

  expect_equal(parse_exactextract_results(dat, varnames),
               parse_exactextract_results(fname, varnames))

  file.remove(fname)
})
