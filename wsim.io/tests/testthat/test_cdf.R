require(testthat)

context("netCDF functions")

test_that("it can write variables and attributes to a netCDF file", {
  fname <- tempfile()
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

  expect_equal(length(cdf$var), 1+1) # include CRS var
  expect_equal(cdf$var[[1]]$name, "my_data")

  expect_equal(ncdf4::ncatt_get(cdf, 0, "yearmon")$value, "201702")
  expect_equal(ncdf4::ncatt_get(cdf, "my_data", "station")$value, "A")

  # Note that our lat-lon input matrix was written to a lon-lat matrix in the netCDF
  expect_equal(ncdf4::ncvar_get(cdf, "my_data"), t(data))

  ncdf4::nc_close(cdf)

  file.remove(fname)
})

test_that("vars can be written from rasters instead of raw matrices", {
  fname <- tempfile()
  data <- matrix(runif(4), nrow=2)
  rast <- raster::raster(data, xmn=-20, xmx=-10, ymn=30, ymx=70)

  write_layer_to_cdf(rast,
                     fname,
                     varname="my_data",
                     attrs=list(list(var="my_data", key="type", val="random"),
                                list(key="file_type", val="results")))

  expect_true(file.exists(fname))

  cdf <- ncdf4::nc_open(fname)

  expect_equal(length(cdf$var), 1+1)
  expect_equal(cdf$var[[1]]$name, "my_data")

  expect_equal(ncdf4::ncatt_get(cdf, 0, "file_type")$value, "results")
  expect_equal(ncdf4::ncatt_get(cdf, "my_data", "type")$value, "random")

  # Note that our lat-lon input matrix was written to a lon-lat matrix in the netCDF
  expect_equal(ncdf4::ncvar_get(cdf, "my_data"), t(data))

  ncdf4::nc_close(cdf)

  file.remove(fname)
})

test_that("we can read attributes and variables from a netCDF file into matrics", {
  fname <- tempfile()
  data <- matrix(runif(4), nrow=2)

  write_vars_to_cdf(list(my_data=data),
                    -40,
                    0,
                    20,
                    70,
                    fname,
                    attrs=list(list(var="my_data", key="station", val="A"),
                               list(key="yearmon", val="201702")))

  v <- read_vars_from_cdf(fname)

  # Grid extent is returned as xmin, xmax, ymin, ymax
  expect_equal(v$extent, c(-40, 0, 20, 70))

  # Global attributes are accessible in $attrs
  expect_equal(v$attrs$yearmon, "201702")

  # Variable attributes are accessible as attrs of the matrix
  expect_equal(attr(v$data$my_data, 'station'), 'A')

  # Make sure our data didn't get messed up (transposed, etc.)
  expect_equal(v$data$my_data, data, check.attributes=FALSE)

  file.remove(fname)
})

test_that("variables that have no dimensions are read in as attributes", {
  fname <- tempfile()

  latdim <- ncdf4::ncdim_def("lat", units="degrees_north", vals=as.double(1:20), longname="Latitude", create_dimvar=TRUE)
  londim <- ncdf4::ncdim_def("lon", units="degrees_east", vals=as.double(30:70), longname="Longitude", create_dimvar=TRUE)

  ncvars <- list(
    crs= ncdf4::ncvar_def(name="crs", units="", dim=list(), missval=NULL, prec="integer"),
    pressure= ncdf4::ncvar_def(name="Pressure", units="kPa", dim=list(latdim, londim))
  )

  ncout <- ncdf4::nc_create(fname, ncvars)
  ncdf4::ncatt_put(ncout, "crs", "code", "EPSG:4326")
  ncdf4::nc_close(ncout)

  v <- read_vars_from_cdf(fname)

  # We only read out one variable, because only one variable has dimensions
  expect_equal(names(v$data), c("Pressure"))

  # The dimenionless variable is read in as attributes
  expect_equal(v$attrs$crs$code, "EPSG:4326")

  file.remove(fname)
})

test_that("we can read multiple variables from a netCDF into a RasterBrick", {
  fname <- tempfile()

  data <- list(
    location= matrix(runif(9), nrow=3),
    scale= matrix(runif(9), nrow=3),
    shape= matrix(runif(9), nrow=3)
  )

  write_vars_to_cdf(data, -70, -30, 20, 60, fname, attrs=list(list(key="distribution", val="fake")))

  brick <- read_brick_from_cdf(fname)

  expect_s4_class(brick, "RasterBrick")
  expect_equal(raster::metadata(brick)$distribution, "fake")

  file.remove(fname)
})
