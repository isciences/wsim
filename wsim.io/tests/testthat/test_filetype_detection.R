require(testthat)

context('File type detection')

test_that('Various types of daily precipitation files are recognized', {
  expect_true(is_ncep_daily_precip('/mnt/fig_rw/WSIM_DEV/daily_precip/1989/PRCP_CU_GAUGE_V1.0GLB_0.50deg.lnx.19890402.gz'))
  expect_true(is_ncep_daily_precip('/mnt/fig_rw/WSIM_DEV/daily_precip/2006/PRCP_CU_GAUGE_V1.0GLB_0.50deg.lnx.20060123RT.gz'))
  expect_true(is_ncep_daily_precip('/mnt/fig_rw/WSIM_DEV/daily_precip/2016/PRCP_CU_GAUGE_V1.0GLB_0.50deg.lnx.20160123.RT'))
  expect_true(is_ncep_daily_precip('/mnt/fig_rw/WSIM_DEV/source/NCEP/Daily_precip/2008/PRCP_CU_GAUGE_V1.0GLB_0.50deg.lnx.20080116.RT.gz'))
  expect_false(is_ncep_daily_precip('/mnt/fig_rw/WSIM_DEV/daily_precip/1989/PRCP_CU_GAUGE_V1.0GLB_0.50deg.lnx.19890402.img'))
})
