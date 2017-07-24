require('testthat')

context("Raster fun apply")

test_that('it can be called with a single raster (1:1)', {
  input <- raster::raster(matrix(c(1,2,3,4), nrow=2), xmn=-74, xmx=-72, ymn=42, ymx=44)
  raster::projection(input) <- '+proj=longlat +ellps=clrk66 +datum=NAD27 +no_defs'

  output <- rsapply(input, function(v) v+1)

  expect_same_extent_crs(input, output)
  expect_equal(raster::values(output), c(2, 4, 3, 5))
})

test_that('it can be called with a single raster (1:M)', {
  input <- raster::raster(matrix(c(1,2,3,4), nrow=2), xmn=-74, xmx=-72, ymn=42, ymx=44)
  raster::projection(input) <- '+proj=longlat +ellps=clrk66 +datum=NAD27 +no_defs'

  output <- rsapply(input, function(v) c(v, v+1))

  expect_same_extent_crs(input, output)
  expect_equal(raster::nlayers(output), 2)
  expect_equal(raster::values(input), raster::values(output[[1]]))
  expect_equal(raster::values(input), raster::values(output[[2]] - 1))
})

test_that('it can be called with a stack (M:1)', {
  input <- raster::stack(raster::raster(matrix(1:4, nrow=2)),
                         raster::raster(matrix(4:1, nrow=2)), xmn=-74, xmx=-72, ymn=42, ymx=44)
  raster::projection(input) <- '+proj=longlat +ellps=clrk66 +datum=NAD27 +no_defs'

  output <- rsapply(input, sum)

  expect_same_extent_crs(input, output)
  expect_equal(raster::values(output), c(5, 5, 5, 5))
})

test_that('it can be called with a stack (M:M)', {
  input <- raster::stack(raster::raster(matrix(1:4, nrow=2)),
                         raster::raster(matrix(4:1, nrow=2)), xmn=-74, xmx=-72, ymn=42, ymx=44)
  raster::projection(input) <- '+proj=longlat +ellps=clrk66 +datum=NAD27 +no_defs'

  output <- rsapply(input, function(vals) {
    c( min(vals), mean(vals), max(vals) )
  }, names=c('min', 'ave', 'max'))

  expect_same_extent_crs(input, output)
  expect_equal(raster::nlayers(output), 3)

  expect_equal(raster::values(output$min), c(1, 2, 2, 1))
  expect_equal(raster::values(output$ave), c(2.5, 2.5, 2.5, 2.5))
  expect_equal(raster::values(output$max), c(4, 3, 3, 4))
})
