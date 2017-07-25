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

  prefix <- '/mnt/fig/WSIM/WSIM_derived_V1.2/DIST/Fit_1950_2009/Bt_RO_Sum_24mo_PE3GEV/Bt_RO_Sum_24mo_gev-'
  location <- raster::raster(paste0(prefix, 'xi_12.img'))
  scale <- raster::raster(paste0(prefix, 'alpha_12.img'))
  shape <- raster::raster(paste0(prefix, 'kappa_12.img'))

  gev_params <- raster::brick(location, scale, shape)

  observed <- raster::raster('/mnt/fig/WSIM/WSIM_derived_V1.2/Observed/SCI/Bt_RO_Sum_24mo/Bt_RO_Sum_24mo_trgt201612.img')

  anomalies <- gevStandardize(gev_params, observed)

  expected_anomalies <- raster::raster('/mnt/fig/WSIM/WSIM_derived_V1.2/Observed/Anom/Bt_RO_Sum_24mo_anom/Bt_RO_Sum_24mo_anom_trgt201612.img')

  expect_equal(raster::values(anomalies), raster::values(expected_anomalies), 1e-6)
  expect_same_extent_crs(observed, anomalies)

  # Also excercise code for stacked inputs
  anomalies2 <- gevStandardize(gev_params, raster::brick(observed, observed))

  expect_equal(raster::values(anomalies), raster::values(anomalies2[[1]]))
  expect_equal(raster::values(anomalies), raster::values(anomalies2[[2]]))

  expect_same_extent_crs(anomalies, anomalies2[[1]])
  expect_same_extent_crs(anomalies, anomalies2[[2]])
})

test_that('This module fits a GEV distribution equivalently to previous WSIM code', {
  isciences_internal()

  observed <- raster::brick('/mnt/fig/WSIM/WSIM_source_V1.2/NCEP.CFSv2/observed/gevParams/T/values_T_month01.grd')
  expected_gev_params <- raster::brick('/mnt/fig/WSIM/WSIM_source_V1.2/NCEP.CFSv2/observed/gevParams/T/gev.stack_T_month01.grd')

  gev_params <- fitGEV(observed, nmin.unique=10, nmin.defined=10, zero.scale.to.na=FALSE)
  expect_equal(unname(raster::as.matrix(gev_params)), unname(raster::as.matrix(expected_gev_params)))
})

test_that('This module bias-corrects a forecast equivalently to previous WSIM code', {
  isciences_internal()

  # load observed and retro GEV fit parameters for June
  obsGEV <- raster::brick('/mnt/fig/WSIM/WSIM_source_V1.2/NCEP.CFSv2/observed/gevParams/T/gev.stack_T_month06.grd')
  retroGEV <- raster::brick('/mnt/fig/WSIM/WSIM_source_V1.2/NCEP.CFSv2/retro/gevParams/tmp2m/gev.stack_tmp2m_month06_lead6.grd')

  # pull a raw forecast from end of December with a 6-month lead (June)
  forecast <- raster::raster('/mnt/fig/WSIM/WSIM_source_V1.2/NCEP.CFSv2/forecast/wsim.20161231/nc/tmp2m/target_201706/tmp2m.trgt201706.lead6.ic2016122506.nc')

  # TODO create wsim.io package and move this stuff in
  raster::extent(forecast) <- c(0, 360, -90, 90)
  forecast <- raster::rotate(forecast)
  forecast <- forecast - 273.15
  forecast <- raster::flip(forecast, 'y')

  corrected <- forecastCorrect(forecast, retroGEV, obsGEV)
  expected_corrected <- raster::raster('/mnt/fig/WSIM/WSIM_source_V1.2/NCEP.CFSv2/forecast/wsim.20161231/corrected_img/T/target_201706/tmp2m.trgt201706.lead6.ic2016122506.img')

  expect_same_extent_crs(corrected, forecast)
  expect_equal(raster::values(corrected), raster::values(expected_corrected))
})
