require(testthat)
require(Rcpp)

context('Integration functions')

integrate <- function(stat, obs) {
  (find_stat(stat))(array(obs, dim=c(1,1,length(obs))))[1]
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
