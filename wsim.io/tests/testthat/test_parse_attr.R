require(testthat)
require(wsim.io)

context("NetCDF attribute parsing")

test_that("Components of the attribute string are parsed correctly", {
  attr_string <- "precipitation:unit=mm"

  expect_equal(parse_attr(attr_string), list(
    var= "precipitation",
    key= "unit",
    val= "mm"
  ))
})

test_that("Global attributes are handled correctly", {
  attr_string <- "distribution=gev"

  expect_equal(parse_attr(attr_string), list(
    var= NULL,
    key= "distribution",
    val= "gev"
  ))
})
