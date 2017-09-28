isciences_internal <- function() {
  if (!file.exists('/mnt/fig/WSIM')) {
    skip("Skipping test that requires ISciences internal resource.")
  }
}

expect_same_extent_crs <- function(r1, r2) {
  expect_equal(raster::extent(r1), raster::extent(r2))
  expect_equal(raster::crs(r1),    raster::crs(r2))
}

expect_na <- function(v) {
  expect_equal(v, as.numeric(NA))
}
