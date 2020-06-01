# Copyright (c) 2018-2020 ISciences, LLC.
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

context('Integration functions')

integrate <- function(stat, obs, weights=NULL) {
  fn <- find_stat(stat)
  x <- array(obs, dim=c(1,1,length(obs)))
  if (is.null(weights)) {
    fn(x)[1]
  } else {
    fn(x, weights)[1]
  }
}

test_that('we can calculate basic stats', {
   obs <- c(1, 3, 5, NA, NA, 22)

   expect_equal(integrate('ave', obs), 7.75)
   expect_equal(integrate('sum', obs), 31)
   expect_equal(integrate('min', obs), 1)
   expect_equal(integrate('max', obs), 22)

   expect_equal(integrate('median', obs), 4)
   expect_equal(integrate('q0', obs), 1)
   expect_equal(integrate('q25', obs), 2.5)
   expect_equal(integrate('q50', obs), 4)
   expect_equal(integrate('q100', obs), 22)
})

test_that('basic stat behavior is as expected when inputs are all undefined', {
  obs <- rep.int(NA, 10)

  expect_na(integrate('ave', obs))
  expect_equal(integrate('sum', obs), 0)
  expect_na(integrate('min', obs))
  expect_na(integrate('max', obs))

  expect_na(integrate('median', obs))
  expect_na(integrate('q50', obs))
})

test_that('we can figure out the number of defined values, and how many are positive', {
  expect_equal(integrate('fraction_defined', c(0,1,2,3)),     1)
  expect_equal(integrate('fraction_defined', c(0,NA,2,3)), 0.75)
  expect_equal(integrate('fraction_defined', c(NA,NA,NA,NA)), 0)

  expect_equal(integrate('fraction_defined_above_zero', c(0,1,2,3)),   3/4)  # 3 out of 4 above zero
  expect_equal(integrate('fraction_defined_above_zero', c(0,NA,2,3)),  2/3)  # 2 out of 3 above zero
  expect_na(   integrate('fraction_defined_above_zero', c(NA,NA,NA,NA)))     # no defined values, so percent is meaningless
})

test_that('weighted quantile function errors out on dimension mismatches', {
  expect_error(integrate('weighted_q50', 1:5, 1:4), 'length of weights')
})

test_that('weighted quantile behaves the same as unweighted quantile when weights are equal', {
  # spatstat weighted.quantile implementation fails this test

  expect_equal(
    sapply(1:100, function(q) integrate(sprintf('q%d', q), 1:5)),
    sapply(1:100, function(q) integrate(sprintf('weighted_q%d', q), 1:5, rep.int(1, 5))))
})

test_that('weighted quantile gives increasing weight to observations with higher weights', {
  expect_true(
    integrate('weighted_q50', 1:5, 1:5) > 3)
})

test_that('weighted quantile results are insensitive to the absolute value of the weights', {
  # Hmisc::wtd.quantile implementation fails this test

  expect_equal(
    integrate('weighted_q50', 1:5, rep.int(0.1, 5)),
    integrate('weighted_q50', 1:5, rep.int(1, 5)))

  expect_equal(
    integrate('weighted_q50', 1:5, 1:5),
    integrate('weighted_q50', 1:5, (1:5)/sqrt(2)))
})

test_that('weighted quantile results continuously increase (instead of exhibiting step-function behavior)', {
  expect_true(
    !is.unsorted(
      sapply(1:100, function(q) {
        integrate(sprintf('weighted_q%d', q), 1:5, 1:5)
      })
    )
  )
})

test_that('weighted quantile distributes weights from missing values among defined values', {
  dat <- runif(20)
  weights <- runif(20)

  missing <- sample(1:length(dat), 4)
  dat[missing] <- NA

  expect_equal(
    integrate('weighted_q25', dat, weights),
    integrate('weighted_q25', dat[!is.na(dat)], weights[!is.na(dat)])
  )
})

test_that('we can sort a 3d array along the 3rd timension, sending NAs to the back', {
  arr <- array(runif(3*7*11), dim=c(3, 7, 11))
  arr[sample.int(length(arr), 0.3*length(arr))] <- NA

  # ensure one set of inputs is fully undefined
  arr[2, 2, ] <- NA

  # ensure one set of inputs is fully defined
  arr[3, 3, ] <- rev(seq_len(dim(arr)[3]))

  expect_equal(
    array_apply(arr, function(x) sort(x, na.last=TRUE)),
    stack_sort(arr)
  )
})

test_that('we can compute the number of defined elements', {
  arr <- array(runif(3*7*11), dim=c(3, 7, 11))
  arr[sample.int(length(arr), 0.3*length(arr))] <- NA

  expect_equal(
    array_apply(arr, function(x) sum(!is.na(x))),
    stack_num_defined(arr)
  )
})

test_that('we can compute minimum and maximum ranks', {
  arr <- array(0, dim=c(2, 2, 10))
  arr[1, 1, ] <- 1:10 # all defined and unique
  arr[1, 2, ] <- c(1, 3, 4, 4, 4, 5, NA, NA, NA, NA)
  arr[2, 1, ] <- NA
  arr[2, 2, ] <- 5

  expect_equal(stack_min_rank(matrix(4, nrow=2, ncol=2), arr),
               rbind(c(4, 3),
                     c(1, 1)))
  expect_equal(stack_max_rank(matrix(4, nrow=2, ncol=2), arr),
               rbind(c(5, 6),
                     c(1, 1)))


})

test_that('rank edge cases behave as expected', {
  minmax_ranks <- function(x, obs) {
    c(stack_min_rank(x, array(obs, dim=c(1, 1, length(obs)))),
      stack_max_rank(x, array(obs, dim=c(1, 1, length(obs)))))
  }

  expect_equal(c(NA_real_, NA_real_),
               minmax_ranks(NA, 1:4))

  expect_equal(c(1, 1),
               minmax_ranks(-1, 4:6))

  expect_equal(c(1, 2),
               minmax_ranks(4, 4:6))

  expect_equal(c(3, 4),
               minmax_ranks(6, 4:6))
})

test_that('stack_select pulls a ragged slice from a 3d array', {
  nx <- 3
  ny <- 2
  nz <- 8
  arr <- array(runif(nx*ny*nz), dim=c(ny, nx, nz))

  start <- rbind(c(3, 1, 0),
                 c(9, 4, -1))
  n <- 5
  fill <- -999
  sel <- stack_select(arr, start, n, fill)

  expect_equal(dim(sel), c(dim(arr)[1:2], n))

  for (i in seq_len(nrow(start))) {
    for (j in seq_len(ncol(start))) {
      first <- start[i, j]
      last <- first + n - 1

      if (first > nz) {
        orig <- rep.int(fill, n)
      } else {
        orig <- c()

        # pre-fill
        if (first < 1) {
          orig <- c(orig, rep.int(fill, 1 - first))
          first <- 1
        }

        if (last <= nz) {
          orig <- c(orig, arr[i, j, first:last])
        } else {
          # post-fill
          orig <- c(orig, arr[i, j, first:nz], rep.int(fill, last - nz))
        }

      }

      expect_equal(orig, sel[i, j, ])
    }
  }
})

test_that('stack_select can also use a callback to fill out-of-range values', {
  nx <- 3
  ny <- 2
  nz <- 8
  arr <- array(0, dim=c(ny, nx, nz))

  start <- rbind(c(3, 1, 0),
                 c(9, 4, -1))
  n <- 5
  sel_constant <- stack_select(arr, start, n, -999)

  # instead of filling with constant values, fill with random values
  set.seed(802)
  sel_runif <- stack_select(arr, start, n, function() runif(1))

  # check that random values filled are same ones we would get by calling
  # from R
  set.seed(802)
  for (j in 1:nx) {
    for (i in 1:ny) {
      x <- sel_runif[i, j, which(sel_constant[i, j, ] == -999)]
      y <- runif(length(x))
      expect_equal(x, y)
    }
  }
})
