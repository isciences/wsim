test_that("we can extract the number of days in a month pertaining to a particular file", {
  expect_equal(get_ndays_from_fname('~/mnt2/WSIM/wsim_gldas/source/GLDAS_NOAH025_M.A194801.020.nc4'),
               31)
  expect_error(get_ndays_from_fname('194801194802'),
               "Multiple dates found in filename: ")
  expect_error(get_ndays_from_fname('194801_asldfk_194802.nc'),
               "Multiple dates found in filename: ")
  expect_error(get_ndays_from_fname('abc1949.nc'),
               "No dates found in filename: ")
})
