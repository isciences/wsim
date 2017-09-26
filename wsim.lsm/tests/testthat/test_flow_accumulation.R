require(testthat)

context('Flow accumulator')

OUT_EAST <- 1L
OUT_SOUTHEAST <- 2L
OUT_SOUTH <- 4L
OUT_SOUTHWEST <- 8L
OUT_WEST <- 16L
OUT_NORTHWEST <- 32L
OUT_NORTH <- 64L
OUT_NORTHEAST <- 128L
OUT_NODATA <- as.integer(NA)

test_that('Flow accumulator functions correctly', {
  nRows <- 2
  nCols <- 3

  weights <- rbind(
    c( 1,  2, 4  ),
    c( 8, 16, 32 )
  )

  directions <- rbind(
    c( OUT_EAST,   OUT_SOUTH, OUT_WEST  ),
    c( OUT_NODATA, OUT_WEST,  OUT_NORTH )
  )

  expected_accumulated <- rbind(
    c( 0,  37, 32 ),
    c( 55, 39, 0  )
  )

  accumulated <- calculateFlow(directions, weights) - weights

  expect_equal(expected_accumulated, accumulated)
})
