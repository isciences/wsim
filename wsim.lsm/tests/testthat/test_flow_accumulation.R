# Copyright (c) 2018-2021 ISciences, LLC.
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

context('Pixel-based flow accumulation')

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

# Helper function to disaggregate a flow direction matrix
disaggregate_directions <- function(dirs, factor) {
  ret <- disaggregate_amount(dirs, factor) * factor * factor
  mode(ret) <- 'integer'
  ret
}

test_that('Downstream cells are identified', {
  directions <- rbind(
    c( OUT_EAST,   OUT_SOUTH, OUT_WEST ),
    c( OUT_NODATA, OUT_WEST,  OUT_NORTH)
  )

  indir <- create_inward_dir_matrix(directions, FALSE, FALSE);

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

  indir <- create_inward_dir_matrix(directions, TRUE, TRUE);
  indir_nowrap <- create_inward_dir_matrix(directions, FALSE, FALSE);

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

  accumulated <- accumulate_flow(directions, weights, FALSE, FALSE) - weights

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

  accumulated_nowrap <- accumulate_flow(directions, weights, FALSE, FALSE) - weights
  accumulated_wrapx  <- accumulate_flow(directions, weights, TRUE,  FALSE) - weights

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

  accumulated_nowrap <- accumulate_flow(directions, weights, FALSE, FALSE) - weights
  accumulated_wrapy  <- accumulate_flow(directions, weights, FALSE, TRUE)  - weights

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

  bt <- accumulate_flow(directions, weights, FALSE, FALSE)

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

  bt <- accumulate_flow(directions, weights, FALSE, FALSE)

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

  bt <- accumulate_flow(directions, weights, FALSE, FALSE)

  expect_equal(bt, rbind(
    c( 5,  4 ),
    c( 4, NA )
  ))
})

test_that('Direction matrix can be integer multiple of flow matrix', {
  weights <- rbind(
    c( 1,  2, 4  ),
    c( 8, 16, 32 )
  )

  directions <- rbind(
    c( OUT_EAST,   OUT_SOUTH, OUT_WEST  ),
    c( OUT_NODATA, OUT_WEST,  OUT_NORTH )
  )

  directions3 <- disaggregate_directions(directions, 3)

  expect_equal(
    accumulate_flow(directions, weights, FALSE, FALSE),
    accumulate_flow(directions3, weights, FALSE, FALSE)
  )
})

test_that('Global 0.125-degree flow direction grid can be shifted and extended to match +/- 180 0.25-degree ERA5 grid', {
  flowdir <- matrix(1L:(2880L*1120L), nrow=1120)
  flowdir_extent <- c(-180, 180, -56, 84)

  era5_extent <- c(-179.875, 180.125, -90.125, 90.125)
  era5_dims <- c(721, 1440)

  flowdir_adj <- adjust_flow_dirs(flowdir, flowdir_extent, era5_extent, era5_dims)

  expect_equal(dim(flowdir_adj), 2 * era5_dims)
  expect_true(is.integer(flowdir_adj))

  filled_northern_lats <- (90.125 - 84) / 0.125
  filled_southern_lats <- (90.125 - 56) / 0.125 - 1

  # northern latitudes filled with NA
  expect_true(all(is.na(flowdir_adj[seq(1, filled_northern_lats), ])))

  # southern latitudes filled with NA
  expect_true(all(is.na(flowdir_adj[seq(nrow(flowdir_adj) - filled_southern_lats, nrow(flowdir_adj), )])))

  # leftmost column of flowdir grid moved to right
  # (western extent moved from -180 to -179.875)
  expect_equal(na.omit(flowdir_adj[, 1]), 1121:2240, check.attributes = FALSE)
  expect_equal(na.omit(flowdir_adj[, 2880]), 1:1120, check.attributes = FALSE)
})

test_that('Global 0.125-degree flow direction grid can be shifted and extended to match 0-360 0.25-degree ERA5 grid', {
  flowdir <- matrix(1L:(2880L*1120L), nrow=1120)
  flowdir_extent <- c(0, 360, -56, 84)

  era5_extent <- c(-0.125, 359.875, -90.125, 90.125)
  era5_dims <- c(721, 1440)

  flowdir_adj <- adjust_flow_dirs(flowdir, flowdir_extent, era5_extent, era5_dims)

  expect_equal(dim(flowdir_adj), 2 * era5_dims)

  # right column of flowdir grid moved to left
  # (western extent moved from 0 to -0.125)
  expect_equal(na.omit(flowdir_adj[, 1]), flowdir[, ncol(flowdir)], check.attributes = FALSE)
  expect_equal(na.omit(flowdir_adj[, 2]), flowdir[, 1], check.attributes = FALSE)
  expect_equal(na.omit(flowdir_adj[, ncol(flowdir_adj)]), flowdir[, ncol(flowdir) - 1], check.attributes = FALSE)
})

test_that('adjust_flow_dirs is a no-op when grids are the same', {
  flowdir <- matrix(1L:(360L*720L), nrow=360)
  flowdir_extent <- c(-180, 180, -90, 90)

  flowdir_adj <- adjust_flow_dirs(flowdir, flowdir_extent, flowdir_extent, dim(flowdir))

  expect_equal(flowdir, flowdir_adj)
  expect_true(is.integer(flowdir_adj))
})
