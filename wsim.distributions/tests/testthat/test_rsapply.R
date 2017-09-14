require('testthat')

context("Raster fun apply")

test_that('it can be called with a single raster (1:1)', {
  input <- raster::raster(matrix(c(1,2,3,4), nrow=2), xmn=-74, xmx=-72, ymn=42, ymx=44)
  raster::projection(input) <- '+proj=longlat +ellps=clrk66 +datum=NAD27 +no_defs'

  output <- rsapply(input, function(v) v+1)

  expect_same_extent_crs(input, output)
  expect_equal(raster::as.matrix(output),
               matrix(c(2, 3, 4, 5), nrow=2))
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

test_that('function is called with a vector containing the elements of each vertical slice', {
  input <- abind::abind(matrix(rep.int(1, 4), nrow=2),
                        matrix(rep.int(2, 4), nrow=2),
                        matrix(rep.int(3, 4), nrow=2),
                        along = 3)

  array_apply(input, function(vals) {
    expect_equal(vals, c(1, 2, 3))
  })
})

test_that('we can apply a distribution to a matrix, producing a matrix', {
  obs <- matrix(17 + c(0:3), nrow=2)
  fit <- abind::abind(matrix(rep.int(17, 4), nrow=2), # mean
                      matrix(rep.int(1,  4), nrow=2), # sd
                      along = 3)
  fit[2,2,] <- NA

  results <- apply_dist_to_array(fit, obs, function(obs, params) {
    pnorm(obs, params[1], params[2])
  })

  expect_equal(results, matrix(c(pnorm(0:2), NA), nrow=2), check.attributes=FALSE)
})

test_that('we can apply a distribution to a matrix, producing a 3D array', {
  obs <- matrix(17 + c(0:3), nrow=2)

  fit <- abind::abind(matrix(rep.int(17, 4), nrow=2), # mean
                      matrix(rep.int(1,  4), nrow=2), # sd
                      along = 3)
  fit[2,2,] <- NA

  results <- apply_dist_to_array(fit, obs, function(obs, params) {
    c(pnorm(obs, params[1], params[2]), 0.5*obs)
  }, when.dist.undefined=c(NA, NA))

  expect_equal(results[,,1], matrix(c(pnorm(0:2), NA), nrow=2), check.attributes=FALSE)
  expect_equal(results[,,2], matrix(c(8.5, 9.0, 9.5, NA), nrow=2), check.attributes=FALSE)
})
