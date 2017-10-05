require('testthat')

context("GEV calculations")

gevParams <- c("location", "scale", "shape")

test_that('We can fit a GEV on a 3D array representing time-series observations', {
  obs <- abind::abind(replicate(30, matrix(rnorm(100, mean=73, sd=5), nrow=5)), along=3)

  fits <- fitGEV(obs)

  # Dimnames should be populated
  expect_equal(dimnames(fits)[[3]], gevParams)

  # Dimensions of output match input, and we have correct number of parameters
  expect_equal(dim(fits), c(nrow(obs), ncol(obs), length(gevParams)))
})

test_that('We can compute the standard anomales for a raster of observations given a RasterStack with the GEV fit parameters', {
  # Take some GEV parameters
  # (Source: WSIM_derived_V1.2/DIST/Fit_1950_2009/Bt_RO_Max_24mo_PE3GEV/Bt_RO_Max_24mo_gev)
  # Cell 42,59
  location <-  7.66e+07
  scale    <-  5.17e+07
  shape    <- -1.18e-01

  gev_params <- abind::abind(list(location= matrix(location),
                                  scale= matrix(scale),
                                  shape= matrix(shape)),
                             along = 3)

  # Take an observed value
  # (Source: WSIM_derived_V1.2/Observed/SCI/Bt_RO_Max_24mo/Bt_RO_Max_24mo_trgt198402.img)
  # Cell 42, 59
  bt_ro_max_24mo <- matrix(c(81544304), nrow=1, ncol=1)

  # Expected anomaly value (z-score)
  # (Source: WSIM_derived_V1.2/Observed/anom/Bt_RO_Max_24mo_anom/Bt_RO_Max_24mo_anom_trgt198402.img)
  # Cell 42,59
  expected_std_anomaly <- -0.246

  std_anomalies <- gevStandardize(gev_params, bt_ro_max_24mo)

  expect_equal(std_anomalies[1,1], expected_std_anomaly, tolerance=1e-3, check.attributes=FALSE)
})

test_that('We can convert an standardized anomaly value into a return period', {
  # Expected return period
  # Source: WSIM_derived_V1.2/Observed/Freq/Bt_RO_Max_24mo_freq/Bt_RO_Max_24mo_freq_trgt198402.img
  # Cell 42, 59
  expected_return_period <- -2.483

  zscore <- -0.246
  return_period <- sa2rp(zscore)

  expect_equal(return_period, expected_return_period, tolerance=1e-3)
})
