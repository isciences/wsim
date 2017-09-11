require('testthat')

context("GEV calculations")

#gevParams <- c("xi", "alpha", "kappa") # location, scale, shape
gevParams <- c("location", "scale", "shape")

test_that('We can fit a GEV on a RasterStack representing time-series observations', {
  obs <- raster::brick(replicate(30, raster::raster(matrix(rnorm(100, mean=73, sd=5), nrow=5),
                                                    xmn=-74, xmx=-72,
                                                    ymn=42,  ymx=47)))
  raster::projection(obs) <- '+proj=longlat +ellps=clrk66 +datum=NAD27 +no_defs'

  fit_matrices <- fitGEV(raster::as.array(obs))
  fits <- raster::stack(lapply(fit_matrices, raster::raster))
  names(fits) <- names(fit_matrices)
  raster::extent(fits) <- raster::extent(obs)
  raster::projection(fits) <- raster::projection(obs)

  # Dimensions of output match input, and we have correct number of parameters
  expect_equal(dim(fits), c(nrow(obs), ncol(obs), length(gevParams)))

  expect_same_extent_crs(fits, obs)
})

test_that('We can compute the standard anomales for a raster of observations given a RasterStack with the GEV fit parameters', {
  # Take some GEV parameters
  # (Source: WSIM_derived_V1.2/DIST/Fit_1950_2009/Bt_RO_Max_24mo_PE3GEV/Bt_RO_Max_24mo_gev)
  # Cell 42,59
  location <-  7.66e+07
  scale    <-  5.17e+07
  shape    <- -1.18e-01

  gev_params <- raster::brick(raster::raster(matrix(location)),
                              raster::raster(matrix(scale)),
                              raster::raster(matrix(shape)))
  names(gev_params) <- c('location', 'scale', 'shape')

  # Take an observed value
  # (Source: WSIM_derived_V1.2/Observed/SCI/Bt_RO_Max_24mo/Bt_RO_Max_24mo_trgt198402.img)
  # Cell 42, 59
  bt_ro_max_24mo <- raster::raster(as.matrix(c(81544304), nrow=1, ncol=1),
                                   xmn=-72, xmx=-71.5,
                                   ymn=44,  ymx=44.5)
  raster::projection(bt_ro_max_24mo) <- '+proj=longlat +ellps=clrk66 +datum=NAD27 +no_defs'

  # Expected anomaly value (z-score)
  # (Source: WSIM_derived_V1.2/Observed/anom/Bt_RO_Max_24mo_anom/Bt_RO_Max_24mo_anom_trgt198402.img)
  # Cell 42,59
  expected_std_anomaly <- -0.246

  std_anomalies <- gevStandardize(gev_params, bt_ro_max_24mo)

  expect_s4_class(std_anomalies, "RasterLayer")
  expect_equal(unname(std_anomalies[1,1,1]), expected_std_anomaly, tolerance=1e-3)

  expect_same_extent_crs(std_anomalies, bt_ro_max_24mo)
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
