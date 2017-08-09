require(testthat)

context('LSM functions')

test_that('all precip accumulates as snow when temp < -1 C', {
  expect_equal(3.2, snow_accum(3.2, -5))
})

test_that('no precip accumulates as snow when temp > -1 C', {
  expect_equal(0.0, snow_accum(3.2, 0.0))
})

test_that('no precip accumulates as snow when temp is unknown', {
  expect_equal(0.0, snow_accum(3.2, NA))
})

test_that('no snowmelt if temp < -1 C', {
  args <- list(
    snowpack = 20,
    melt_month = 0,
    T = -2,
    z = 520
  )
  expect_equal(0.0, do.call(snow_melt, args))
})

test_that('no snowmelt if elevation undefined', {
  args <- list(
    snowpack = 20,
    melt_month = 0,
    T = 20,
    z = NA
  )
  expect_true(is.na(do.call(snow_melt, args)))
})

test_that('no snowmelt if melt_month undefined', {
  args <- list(
    snowpack = 20,
    melt_month = NA,
    T = 20,
    z = 520
  )
  expect_true(is.na(do.call(snow_melt, args)))
})

test_that('all snow melts if elev < 500', {
  args <- list(
    snowpack = 20,
    melt_month = 0,
    T = 2,
    z = 499
  )
  expect_equal(20, do.call(snow_melt, args))

  args <- list(
    snowpack = 20,
    melt_month = 1,
    T = 2,
    z = 499
  )
  expect_equal(20, do.call(snow_melt, args))
})

test_that('above 500 m elev, snowmelt depends on melt month', {
  args <- list(
    snowpack = 20,
    melt_month = 1,
    T = 2,
    z = 501
  )
  expect_equal(10, do.call(snow_melt, args))

  args <- list(
    snowpack = 20,
    melt_month = 2,
    T = 2,
    z = 501
  )
  expect_equal(20, do.call(snow_melt, args))
})
