require(testthat)

context("I/O Regression Tests")

test_that("We can read a file of NCEP daily precipitation", {
  filename <- '/mnt/fig/WSIM/WSIM_source_V1.2/NCEP/Daily_precip/Originals/2017/PRCP_CU_GAUGE_V1.0GLB_0.50deg.lnx.20170521.RT'

  precip <- readNCEP_Daily_P(filename)

  row_btv <- (180+73.2)*720/360 # 0.5-degree cells, starting at antimeridian and working west
  col_btv <- (90-44.5)*360/180  # 0.5-degree cells, starting at north pole

  expect_equal(dim(precip), c(720, 360))       # 0.5-degree lon/lat
  expect_equal(precip[row_btv, col_btv]/10, 0) # no rain in Burlingotn, VT

  expect_equal(max(precip, na.rm = TRUE), 1076.367, tolerance=1e-3)
})

test_that("We can read a gridded binary .mon file", {
  filename <- '/mnt/fig/WSIM/WSIM_source_V1.2/NCEP/originals/t.201701.mon'

  temp <- readMonFile(filename)

  row_btv <- (90-44.5)*360/180 # 0.5-degree cells, starting at north pole
  col_btv <- (180-73.2)*720/360 # 0.5-degree cells, starting at antimeridian and working east

  expect_equal(unname(temp[row_btv, col_btv]), -3.21, tolerance=1e-3) # 26.2 F in Burlington, VT
  expect_equal(raster::extent(temp), raster::extent(-180, 180, -90, 90))
  expect_equal(raster::projection(temp), raster::projection(raster::raster())) # wgs84
})
