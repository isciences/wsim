require('testthat')

context("GEV regression tests")

# The tests in this file verify that the wsim.distributions model can produce
# output equivalant to that produced by previous ISciences processes.

# These tests reference files on the ISciences network and will be skipped
# if those files are not available.
#
# Unlike the unit tests included elsewhere, these regression tests may
# operate on large datasets and may take a long time to run.
#
# In addition to verifying that output is unchanged, these test cases may be
# useful for testing performance improvements to this module.
test_that('This module computes equivalent anomalies to previous WSIM code', {
  isciences_internal()

  prefix <- paste0(testdata, '/Bt_RO_Sum_24mo_gev-')
  fit <- list(
    location= wsim.io::read_vars(paste0(prefix, 'xi_12.img'))$data[[1]],
    scale= wsim.io::read_vars(paste0(prefix, 'alpha_12.img'))$data[[1]],
    shape= wsim.io::read_vars(paste0(prefix, 'kappa_12.img'))$data[[1]]
  )

  gev_params <- abind::abind(fit, along=3)

  observed <- wsim.io::read_vars(paste0(testdata, '/Bt_RO_Sum_24mo_trgt201612.img'))$data[[1]]

  anomalies <- standard_anomaly('gev', gev_params, observed)
  return_periods <- sa2rp(anomalies)

  expected_anomalies <- wsim.io::read_vars(paste0(testdata, '/Bt_RO_Sum_24mo_anom_trgt201612.img'))$data[[1]]
  expected_return_periods <- wsim.io::read_vars(paste0(testdata, '/Bt_RO_Sum_24mo_freq_trgt201612.img'))$data[[1]]

  expect_equal(anomalies, expected_anomalies, tolerance=1e-6, check.attributes=FALSE)
  expect_equal(return_periods, expected_return_periods, tolerance=1e-6, check.attributes=FALSE)
})

test_that('This module fits a GEV distribution equivalently to previous WSIM code', {
  isciences_internal()

  observed <- raster::as.array(raster::brick(paste0(testdata, '/values_T_month01.grd')))
  expected_gev_params <- raster::as.array(raster::brick(paste0(testdata, '/gev.stack_T_month01.grd')))

  gev_params <- fitGEV(observed, nmin.unique=10, nmin.defined=10, zero.scale.to.na=FALSE)
  expect_equal(gev_params, expected_gev_params, check.attributes=FALSE)
})

test_that('This module bias-corrects a forecast equivalently to previous WSIM code', {
  isciences_internal()

  # load observed and retro GEV fit parameters for June
  obsGEV <- raster::as.array(raster::brick(paste0(testdata, '/gev.stack_T_month06.grd')))
  dimnames(obsGEV) <- list(NULL, NULL, list('location', 'scale', 'shape'))

  retroGEV <- raster::as.array(raster::brick(paste0(testdata, '/gev.stack_tmp2m_month06_lead6.grd')))
  dimnames(retroGEV) <- list(NULL, NULL, list('location', 'scale', 'shape'))

  # pull a raw forecast from end of December with a 6-month lead (June)
  forecast <- wsim.io::read_vars(paste0(testdata, '/tmp2m.trgt201706.lead6.ic2016122506.nc'))$data[[1]] - 273.15
  # the file used as an example is incorrectly flipped about the y-axis.
  forecast <- raster::as.matrix(raster::flip(raster::raster(forecast), 'y'))

  corrected <- forecast_correct('gev', forecast, retroGEV, obsGEV)
  expected_corrected <- wsim.io::read_vars(paste0(testdata, '/tmp2m.trgt201706.lead6.ic2016122506.img'))$data[[1]]

  expect_equal(corrected, expected_corrected, check.attributes=FALSE)
})
