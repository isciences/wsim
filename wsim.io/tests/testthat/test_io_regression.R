require(testthat)

context("I/O Regression Tests")

test_that("We can read a file of NCEP daily precipitation", {
  filename <- '/mnt/fig/WSIM/WSIM_source_V1.2/NCEP/Daily_precip/Originals/2017/PRCP_CU_GAUGE_V1.0GLB_0.50deg.lnx.20170521.RT'

  precip <- readNCEP_Daily_P(filename)

  expect_equal(dim(precip), c(720, 360)) # 0.5-degree lat/lon
  expect_equal(precip[269, 214]/10, 6.842, tolerance=1e-3) # 6.8 mm of rain in Burlington, VT

  expect_equal(max(precip, na.rm = TRUE), 1076.367, tolerance=1e-3)
})
