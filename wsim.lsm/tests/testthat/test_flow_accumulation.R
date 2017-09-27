require(testthat)
require(Rcpp)

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

IN_EAST <- 16;
IN_SOUTHEAST <- 32;
IN_SOUTH <- 64;
IN_SOUTHWEST <- 128;
IN_WEST <- 1;
IN_NORTHWEST <- 2;
IN_NORTH <- 4;
IN_NORTHEAST <- 8;
IN_NONE <- 0;

test_that('Downstream cells are identified', {
  directions <- rbind(
    c( OUT_EAST,   OUT_SOUTH, OUT_WEST ),
    c( OUT_NODATA, OUT_WEST,  OUT_NORTH)
  )

  indir <- createInwardDirMatrix(directions, FALSE, FALSE);

  expected_indir <- rbind(
    c( IN_NONE, IN_EAST + IN_WEST, IN_SOUTH ),
    c( IN_EAST, IN_NORTH,          IN_NONE)
  )

  expect_equal(indir, expected_indir);
})

test_that('Downstream cells are identified with wrapping', {
  directions <- rbind(
    c(OUT_NORTHWEST, OUT_SOUTH, OUT_SOUTH,  OUT_NORTH, OUT_SOUTH),
    c(OUT_SOUTH,     OUT_EAST,  OUT_NODATA, OUT_SOUTH, OUT_EAST)
  )

  indir <- createInwardDirMatrix(directions, TRUE, TRUE);
  indir_nowrap <- createInwardDirMatrix(directions, FALSE, FALSE);

  expected_indir <- rbind(
    c( IN_NONE,            IN_SOUTH,            IN_NONE, IN_SOUTHEAST, IN_NONE             ),
    c( IN_WEST, IN_NORTH + IN_NORTH, IN_WEST + IN_NORTH,      IN_NONE, IN_NORTH + IN_NORTH )
  )

  expected_indir_nowrap <- rbind(
    c ( IN_NONE, IN_NONE,             IN_NONE, IN_NONE, IN_NONE ),
    c ( IN_NONE, IN_NORTH, IN_WEST + IN_NORTH, IN_NONE, IN_NORTH )
  )

  expect_equal(indir_nowrap, expected_indir_nowrap)
  expect_equal(indir, expected_indir)
})


test_that('Flow accumulates correctly without wrapping', {

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

  accumulated <- calculateFlow(directions, weights, FALSE, FALSE) - weights

  expect_equal(expected_accumulated, accumulated)
})

test_that('We can optionally wrap flow around the X dimension', {

  weights <- rbind(
    c(1, 2),
    c(4, 8)
  )

  directions <- rbind(
    c(OUT_WEST,   OUT_SOUTH),
    c(OUT_NODATA, OUT_WEST)
  )

  accumulated_nowrap <- calculateFlow(directions, weights, FALSE, FALSE) - weights
  accumulated_wrapx  <- calculateFlow(directions, weights, TRUE,  FALSE) - weights

  expect_equal(accumulated_nowrap, rbind(
    c(0,  0),
    c(10, 2)
  ))

  expect_equal(accumulated_wrapx, rbind(
    c(0,  1),
    c(11, 3)
  ))
})

test_that('We can optionally wrap flow around the Y dimension', {

  weights <- rbind(
    c(1,   2,   4,   8, 16 ),
    c(32, 64, 128, 256, 512)
  )

  directions <- rbind(
    c(OUT_NORTH, OUT_SOUTH, OUT_SOUTH,  OUT_NORTH, OUT_SOUTH),
    c(OUT_SOUTH, OUT_EAST,  OUT_NODATA, OUT_SOUTH, OUT_WEST)
  )

  accumulated_nowrap <- calculateFlow(directions, weights, FALSE, FALSE) - weights
  accumulated_wrapy  <- calculateFlow(directions, weights, FALSE, TRUE)  - weights

  expect_equal(accumulated_nowrap, rbind(
    c(0, 0, 0,    0,  0),
    c(0, 2, 70, 528, 16)
  ))

  expect_equal(accumulated_wrapy, rbind(
    c(0, 8,     0,   0,  1),
    c(0, 827, 895, 561, 49)
  ))

})

test_that('NA weights are interpreted as zero, rather than propagating NA downstream', {
  weights <- rbind(
    c(1,  NA),
    c(NA,  4)
  )

  directions <- rbind(
    c(OUT_NODATA, OUT_SOUTHWEST),
    c(OUT_NORTH,  OUT_NORTH)
  )

  bt <- calculateFlow(directions, weights, FALSE, FALSE)

  expect_equal(bt, rbind(
    c( 5,  4 ),
    c( 4,  4 )
  ))
})

test_that('NA weights that do not convey flow remain at NA', {
  weights <- rbind(
    c(1,   4),
    c(NA, NA)
  )

  directions <- rbind(
    c(OUT_NODATA, OUT_SOUTHWEST),
    c(OUT_NORTH,  OUT_NODATA)
  )

  bt <- calculateFlow(directions, weights, FALSE, FALSE)

  expect_equal(bt, rbind(
    c( 5,  4 ),
    c( 4, NA )
  ))
})

test_that('Headwater NAs are not conveyed downstream', {
  weights <- rbind(
    c(1,   4),
    c(NA, NA)
  )

  directions <- rbind(
    c(OUT_NODATA, OUT_SOUTHWEST),
    c(OUT_NORTH,  OUT_NORTH)
  )

  bt <- calculateFlow(directions, weights, FALSE, FALSE)

  expect_equal(bt, rbind(
    c( 5,  4 ),
    c( 4, NA )
  ))
})
