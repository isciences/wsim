require(testthat)

context('Time-integration regression tests')

test_that('This module performs time-integration equivalently to previous WSIM code', {
  isciences_internal()

  # Load up 6 months of observed data
  root <- '/mnt/fig/WSIM/WSIM_derived_V1.2/Observed/SCI/'
  param <- 'Bt_RO'

  input_files <- wsim.io::expand_inputs(paste0(testdata, '/Bt_RO_trgt20160[1-6].img'))
  inputs <- raster::brick(sapply(input_files, raster::raster))

  # Integrate the 6 months of data
  summaries <- c('Min', 'Max', 'Sum')

  integrated <- rsapply(inputs, function(vals) {
    c( min(vals), max(vals), sum(vals) )
  }, names=summaries)

  # Load up data integrated by previous code
  expected_files <- paste0(testdata, '/', param, '_', summaries, '_6mo_trgt201606.img')
  expected <- raster::brick(sapply(expected_files, raster::raster))
  names(expected) <- summaries

  expect_same_extent_crs(integrated, inputs)

  # Verify that integrated outputs match what was previously computed
  expect_equal(raster::values(integrated$Min), raster::values(expected$Min))
  expect_equal(raster::values(integrated$Max), raster::values(expected$Max))
  expect_equal(raster::values(integrated$Sum), raster::values(expected$Sum), tolerance=1e-7)
})

test_that('This module computes pWetDays equivalently to previous WSIM code', {
  isciences_internal()

  # Subtract 1 from precip values (which are in tenths of millimeters) to ignore "trace" precip
  inputs <- wsim.io::expand_inputs(paste0(testdata, '/*201705*.RT::1@[x-1]->Pr'))
  data <- wsim.io::read_vars_to_cube(inputs)

  pWetDays <- array_apply(data, find_stat('fraction_defined_above_zero'))

  expected <- wsim.io::read_vars(paste0(testdata, '/pWetDays_201705.img'))$data[[1]]

  expect_equal(pWetDays, expected, tolerance=1e-3, check.attributes=FALSE)
})
