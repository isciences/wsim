require(testthat)

context("GEV calculations")

gevParams <- c("location", "scale", "shape")

test_that('We can fit a GEV on a 3D array representing time-series observations', {
  obs <- abind::abind(replicate(30, matrix(rnorm(100, mean=73, sd=5), nrow=5)), along=3)

  fits <- fit_cell_distributions('gev', obs)

  # Dimnames should be populated
  expect_equal(dimnames(fits)[[3]], gevParams)

  # Dimensions of output match input, and we have correct number of parameters
  expect_equal(dim(fits), c(nrow(obs), ncol(obs), length(gevParams)))
})

test_that('GEV fitting works with observed values of zero', {
  obs <- c(0, 0, 0, 0, 0, 1.8704651594162, 0.157944425940514, 3.850834608078, 0, 0, 0, 0, 2.85696363449097, 0.261146754026413, 2.0380973815918, 0, 0.258344888687134, 0, 0.399902075529099, 3.37983632087708, 0, 0, 2.2133469581604, 0, 1.93104267120361, 0.367044538259506, 0, 0, 0.520134270191193)
  obs <- array(obs, dim=c(1,1,length(obs)))

  fit <- fit_cell_distributions('gev', obs)[1,1, ]

  expect_length(fit, 3)
  expect_false(any(is.na(fit)))
})

test_that('If we do not have minimum number of unique observations, fall back to the median', {
  obs <- c(1.8704651594162, 0.157944425940514, 3.850834608078, 2.85696363449097, 0.261146754026413, 2.0380973815918, 0.258344888687134, 0.399902075529099, 3.37983632087708, 2.2133469581604, 1.93104267120361, 0.367044538259506, 0.520134270191193)
  obs <- array(obs, dim=c(1,1,length(obs)))

  fit <- fit_cell_distributions('gev', obs)[1,1, ]
  expect_length(fit, 3)
  expect_false(any(is.na(fit)))

  fit <- fit_cell_distributions('gev', obs, nmin.unique=15)[1,1, ]
  expect_length(fit, 3)
  expect_equal(fit[1], median(obs), check.attributes=FALSE)
  expect_true(is.na(fit[2]))
  expect_true(is.na(fit[3]))
})

test_that('If we do not have a minimum number of defined values, do not perform a fit', {
  obs <- c(NA, NA, NA, NA, 1.87, 0.157, 3.85, 2.86, 0.26, 2.04, 0.26, 0.40, 3.38)
  obs <- array(obs, dim=c(1,1,length(obs)))

  fit <- fit_cell_distributions('gev', obs, nmin.unique=5, nmin.defined=10)[1,1, ]
  expect_length(fit, 3)
  expect_true(all(is.na(fit)))

  fit <- fit_cell_distributions('gev', obs, nmin.unique=5, nmin.defined=9)[1,1, ]
  expect_length(fit, 3)
  expect_false(any(is.na(fit)))
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
