require(testthat)
require(wsim.io)

context("File writability")

test_that("Writability of a file is correctly identified", {
  expect_true(can_write(tempfile()))
  expect_false(can_write('/root/shouldnt_write_here'))
})

test_that("Checking writability doesn't leave any traces", {
  fname <- tempfile()
  can_write(fname)
  expect_false(file.exists(fname))
})

test_that("Checking writability doesn't affect an existing file", {
  fname <- tempfile()

  fileConn <- file(fname)
  write("cupcake", file=fileConn)
  close(fileConn)

  can_write(fname)

  fileConn <- file(fname)
  contents <- trimws(readChar(fileConn, nchars=100))
  close(fileConn)

  file.remove(fname)

  expect_equal(contents, "cupcake")
})

