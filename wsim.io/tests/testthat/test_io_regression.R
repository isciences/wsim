require(testthat)
require(wsim.io)

context("I/O Regression Tests")

test_that("We can read a file of NCEP daily precipitation", {
  isciences_internal()

  filename <- '/mnt/fig/WSIM/WSIM_source_V1.2/NCEP/Daily_precip/Originals/2017/PRCP_CU_GAUGE_V1.0GLB_0.50deg.lnx.20170521.RT'

  precip <- readNCEP_Daily_P(filename)

  row_btv <- (180+73.2)*720/360 # 0.5-degree cells, starting at antimeridian and working west
  col_btv <- (90-44.5)*360/180  # 0.5-degree cells, starting at north pole

  expect_equal(dim(precip), c(720, 360))       # 0.5-degree lon/lat
  expect_equal(precip[row_btv, col_btv]/10, 0) # no rain in Burlington, VT

  expect_equal(max(precip, na.rm = TRUE), 1076.367, tolerance=1e-3)
})

test_that("We can read a CFSv2 forecast", {
  isciences_internal()

  filename <- '/mnt/fig/WSIM/WSIM_source_V1.2/NCEP.CFSv2/forecast/wsim.20161231/nc/tmp2m/target_201706/tmp2m.trgt201706.lead6.ic2016122506.nc'
  forecast <- read_cfs_from_cdf(filename)

  forecast_rast <- raster::raster(forecast$data$tmp2m,
                                  xmn=forecast$extent[1],
                                  xmx=forecast$extent[2],
                                  ymn=forecast$extent[3],
                                  ymx=forecast$extent[4])

  btv_fahrenheit <- raster::extract(forecast_rast, cbind(-73.2, 44.5))*9/5+32

  expect_equal(btv_fahrenheit, 58.96121, tolerance=1e-2, check.attributes=FALSE)
})

test_that("We can read a gridded binary .mon file", {
  isciences_internal()

  filename <- '/mnt/fig/WSIM/WSIM_source_V1.2/NCEP/originals/t.201701.mon::1->temp'

  v <- read_vars(filename)

  row_btv <- round((90-44.5)*360/180)  # 0.5-degree cells, starting at north pole
  col_btv <- round((180-73.2)*720/360) # 0.5-degree cells, starting at antimeridian and working east

  expect_equal(v$data$temp[row_btv, col_btv], -3.21, tolerance=1e-3) # 26.2 F in Burlington, VT
  expect_equal(v$extent, c(-180, 180, -90, 90))
})
