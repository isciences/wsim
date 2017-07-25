require('testthat')

context('Time-integration regression tests')

test_that('This module performs time-integration equivalently to previous WSIM code', {
  isciences_internal()

  # Load up 6 months of observed data
  root <- '/mnt/fig/WSIM/WSIM_derived_V1.2/Observed/SCI/'
  param <- 'Bt_RO'

  input_files <- paste0(root, param, '/', param, '_trgt2016', sprintf('%02d', 1:6), '.img')
  inputs <- raster::brick(sapply(input_files, raster::raster))

  # Integrate the 6 months of data
  summaries <- c('Min', 'Max', 'Sum')

  integrated <- rsapply(inputs, function(vals) {
    c( min(vals), max(vals), sum(vals) )
  }, names=summaries)

  # Load up data integrated by previous code
  expected_files <- paste0(root, param, '_', summaries, '_6mo/', param, '_', summaries, '_6mo_trgt201606.img')
  expected <- raster::brick(sapply(expected_files, raster::raster))
  names(expected) <- summaries

  expect_same_extent_crs(integrated, inputs)

  # Verify that integrated outputs match what was previously computed
  expect_equal(raster::values(integrated$Min), raster::values(expected$Min))
  expect_equal(raster::values(integrated$Max), raster::values(expected$Max))
  expect_equal(raster::values(integrated$Sum), raster::values(expected$Sum), tolerance=1e-7)
})
