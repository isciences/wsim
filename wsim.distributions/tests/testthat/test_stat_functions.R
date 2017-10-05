require(testthat)

context("Statistics functions")

test_that('cdfgev equivalent to version in lmom package', {
  do_test <- function(x, location, scale, shape) {
    expect_equal(wsim_cdfgev(x, location, scale, shape),
                 lmom::cdfgev(x, c(location, scale, shape)))
  }  
  
  do_test(NA, 1, 2, 3)
  
  do_test(0.5, 1, 2, 3)
  
  # special case, shape=0
  do_test(0.5, 1, 2, 0)
})

test_that('quagev equivalent to version in lmom package', {
  do_test <- function(x, location, scale, shape) {
    expect_equal(wsim_quagev(x, location, scale, shape),
                 lmom::quagev(x, c(location, scale, shape)))
  }  
  
  do_test(NA, 1, 2, 3)  
  
  do_test(0.5, 1, 2, 3)  
  
  # special case, shape=0
  do_test(0.5, 1, 2, 0)
})

test_that('quape3 equivalent to version in lmom package', {
  do_test <- function(x, location, scale, shape) {
    expect_equal(wsim_quape3(x, location, scale, shape),
                 lmom::quape3(x, c(location, scale, shape)))
  }  
  
  do_test(NA, 1, 2, 3)  
  
  do_test(0.5, 1, 2, 3)  
  
  # special case, shape near zero
  do_test(0.5, 1, 2, 1e-12)
})

test_that('cdfpe3 equivalent to version in lmom package', { do_test <- function(x, location, scale, shape) {
    expect_equal(wsim_cdfpe3(x, location, scale, shape),
                 lmom::cdfpe3(x, c(location, scale, shape)))
  }  
  
  do_test(NA, 1, 2, 3)
  
  do_test(0.5, 1, 2, 3)
  
  # special case where shape near-zero
  do_test(0.5, 1, 2, 1e-12)
  
  # special case where shape negative
  do_test(0.5, 1, 2, -3)
  
  # special case where z very negative
  do_test(-1e4, 1, 2, 3)
})