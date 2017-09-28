require('testthat')

context('Integration functions')

integrate <- function(stat, obs) {
  (find_stat(stat))(obs)
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

