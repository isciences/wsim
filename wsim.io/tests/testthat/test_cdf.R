require(testthat)

context("netCDF functions")

test_that("it can write variables and attributes to a netCDF file", {
  fname = tempfile()
  data <- matrix(runif(4), nrow=2)

  write_vars_to_cdf(list(my_data=data),
                    -40,
                    0,
                    20,
                    70,
                    fname,
                    attrs=list(list(var="my_data", key="station", val="A"),
                               list(key="yearmon", val="201702")))

  expect_true(file.exists(fname))

  cdf <- ncdf4::nc_open(fname)

  expect_equal(length(cdf$var), 1)
  expect_equal(cdf$var[[1]]$name, "my_data")

  expect_equal(ncdf4::ncatt_get(cdf, 0, "yearmon")$value, "201702")
  expect_equal(ncdf4::ncatt_get(cdf, "my_data", "station")$value, "A")

  ncdf4::nc_close(cdf)

  file.remove(fname)
})

test_that("vars can be written from rasters instead of raw matrices", {
  fname = tempfile()
  data <- matrix(runif(4), nrow=2)
  rast <- raster::raster(data, xmn=-20, xmx=-10, ymn=30, ymx=70)

  write_layer_to_cdf(rast,
                     fname,
                     varname="my_data",
                     attrs=list(list(var="my_data", key="type", val="random"),
                                list(key="file_type", val="results")))

  expect_true(file.exists(fname))

  cdf <- ncdf4::nc_open(fname)

  expect_equal(length(cdf$var), 1)
  expect_equal(cdf$var[[1]]$name, "my_data")

  expect_equal(ncdf4::ncatt_get(cdf, 0, "file_type")$value, "results")
  expect_equal(ncdf4::ncatt_get(cdf, "my_data", "type")$value, "random")

  ncdf4::nc_close(cdf)

  file.remove(fname)
})
