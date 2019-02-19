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

test_that('Reclassify behaves on malformed inputs', {
  x <- 1:4 
  
  # one-column matrix
  expect_error(reclassify(x, matrix(1:4, ncol=1), TRUE), 
               'should be specified using a two-column')
  
  # zero-row matrix
  expect_equal(rep.int(NA_real_, 4),
               reclassify(x, array(dim=c(0,2)), TRUE))
})

test_that('Day-of-year aggregation computes a correct result', {
  x <- rbind(
    c(10, 20, 4,    NA, NA, NA),
    c(30, NA, 330, 331, NA, NA)
  )  
  
  y <- aggregate_mean_doy(x, 2)
  
  expect_equal(y, 
               matrix(
                 c(
                   mean_doy(c(10, 20, 30)),
                   mean_doy(c(4, 330, 331)),
                   NA),
                 nrow=1))
})

test_that('Sum aggregation computes a correct result', {
  x <- rbind(
    c(10, 20, 4,    NA, NA, NA),
    c(30, NA, 330, 331, NA, NA)
  )  
  
  y <- aggregate_sum(x, 2)
  
  expect_equal(y, 
               matrix(
                 c(
                   sum(c(10, 20, 30),  na.rm=TRUE),
                   sum(c(4, 330, 331), na.rm=TRUE),
                   NA),
                 nrow=1))
})

test_that('Mean aggregation computes a correct result', {
  x <- rbind(
    c(10, 20, 4,    NA, NA, NA),
    c(30, NA, 330, 331, NA, NA)
  )  
  
  y <- aggregate_mean(x, 2)
  
  expect_equal(y, 
               matrix(
                 c(
                   mean(c(10, 20, 30),  na.rm=TRUE),
                   mean(c(4, 330, 331), na.rm=TRUE),
                   NA),
                 nrow=1))
})

test_that('Aggregation functions produce errors on bad inputs', {
  x <- array(12*8, dim=c(12, 8))
  
  for (aggregate_fn in c(aggregate_mean, aggregate_sum, aggregate_mean_doy)) {
    expect_error(
      aggregate_fn(x, 0),
      'must be a positive integer')
    
    expect_error(
      aggregate_fn(x, -1),
      'must be a positive integer')
    
    expect_error(
      aggregate_fn(x, 3),
      'must .* evenly divisible')
  }

})

test_that('Disaggregate generates correct results', {
  x <- rbind(
    c(1, 4, 7,  10),
    c(2, 5, NA, 11),
    c(3, 6, 9,  12)
  )
  
  y <- disaggregate(x, 2)
  
  expect_equal(y,
               rbind(c(1, 1, 4, 4, 7,   7, 10, 10),
                     c(1, 1, 4, 4, 7,   7, 10, 10),
                     c(2, 2, 5, 5, NA, NA, 11, 11),
                     c(2, 2, 5, 5, NA, NA, 11, 11),
                     c(3, 3, 6, 6, 9,   9, 12, 12),
                     c(3, 3, 6, 6, 9,   9, 12, 12)
                     ))
})

test_that('Disaggregate throws errors on invalid inputs', {
  x <- array(1:12, dim=c(3, 4))
  
  expect_error(disaggregate(x,  0), 'Invalid .* factor')
  expect_error(disaggregate(x, -1), 'Invalid .* factor')
})