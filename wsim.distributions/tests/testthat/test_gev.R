# Copyright (c) 2018 ISciences, LLC.
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

test_that('We return NA if our input observations are un-fittable', {
  obs <- c(2.782796e-12, 8.098471e-11, 1.303885e-11, 1.842496e-12,
           6.766966e-13, 6.642337e-13, 4.328186e-13, 2.494756e-13,
           2.253246e-13, 1.103293e-13, 2.682839e-13, 9.323600e-14,
           7.455876e-14, 2.546827e-13, 8.882821e-13, 1.244434e-13,
           3.975554e-13, 3.842592e+06)
  obs <- array(obs, dim=c(1,1,length(obs)))
  error_logger_called <- FALSE

  fit <- fit_cell_distributions('gev', obs, log.errors=function(e) {
    error_logger_called <<- TRUE
  })[1,1, ]

  expect_length(fit, 3)
  expect_true(all(is.na(fit)))
  expect_true(error_logger_called)
})

test_that('We can compute a standardized anomaly, given an observation and fit parameters', {
  # Take some GEV parameters
  # (Source: WSIM_derived_V1.2/DIST/Fit_1950_2009/Bt_RO_Max_24mo_PE3GEV/Bt_RO_Max_24mo_gev-*_02')
  # Cell 59,42
  location <-  7.66e+07
  scale    <-  5.17e+07
  shape    <- -1.18e-01

  # Take an observed value
  # (Source: WSIM_derived_V1.2/Observed/SCI/Bt_RO_Max_24mo/Bt_RO_Max_24mo_trgt198402.img)
  # Cell 59, 42
  bt_ro_max_24mo <- 81544304

  # Expected anomaly value (z-score)
  # (Source: WSIM_derived_V1.2/Observed/anom/Bt_RO_Max_24mo_anom/Bt_RO_Max_24mo_anom_trgt198402.img)
  # Cell 59, 42
  expected_std_anomaly <- -0.246

  std_anomaly <- standard_anomaly('gev', c(location, scale, shape), bt_ro_max_24mo)

  expect_equal(std_anomaly, expected_std_anomaly, tolerance=1e-3, check.attributes=FALSE)
})

test_that('We can compute standardized anomalies, given a matrix of observations and a 3D array of fit parameters', {
  # WSIM_derived_V1.2/DIST/Fit_1950_2009/Bt_RO_Max_24mo_PE3GEV/Bt_RO_Max_24mo_gev-xi_02.img)[59:60,42:44]
  location <- rbind(
    c(76619512, 76800640,  144836208),
    c(69696832, 130211720,  96399960)
  )

  # WSIM_derived_V1.2/DIST/Fit_1950_2009/Bt_RO_Max_24mo_PE3GEV/Bt_RO_Max_24mo_gev-alpha_02.img)[59:60,42:44]
  scale <- rbind(
    c(51664956, 51632312, 103790888),
    c(50352400, 90703368,  61651560)
  )

  # WSIM_derived_V1.2/DIST/Fit_1950_2009/Bt_RO_Max_24mo_PE3GEV/Bt_RO_Max_24mo_gev-kappa_02.img)[59:60,42:44]
  shape <- rbind(
    c(0.1177705, -0.1117633, -0.08378604),
    c(0.2131017,  0.2907265,  0.31255856)
  )

  # WSIM_derived_V1.2/Observed/SCI/Bt_RO_Max_24mo/Bt_RO_Max_24mo_trgt198402.img[59:60,42:44]
  obs <- rbind(
    c(81544304,  90196464, 174569296),
    c(92091520, 146239712, 123629424)
  )

  # WSIM_derived_V1.2/Observed/anom/Bt_RO_Max_24mo_anom/Bt_RO_Max_24mo_anom_trgt198402.img[59:60,42:44]
  expected_std_anomaly <- rbind(
    c(-0.24636453, -0.09788399, -0.07341547),
    c( 0.08620062, -0.16551957,  0.09294514)
  )

  std_anomaly <- standard_anomaly('gev', abind::abind(location, scale, shape, along=3), obs)
  expect_equal(std_anomaly, expected_std_anomaly, tolerance=1e-2, check.attributes=FALSE)
})

test_that('We get a comprehensible error message if the distribution passed to stanard_anomaly is invalid', {
  expect_error(standard_anomaly('gevv',
                                array(c(1, 1, 1), dim=c(1,1,3)),
                                matrix(0.5)),
               'No quantile function available')
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
