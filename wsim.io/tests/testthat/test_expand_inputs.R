require(testthat)

context('Input expansion')

test_that('We can use glob expansion', {
  dirname <- tempfile('dir')
  dir.create(dirname)

  files <- c(file.path(dirname, 'saucisse'),
             file.path(dirname, 'saucisson'))

  file.create(files)

  # Basic wildcard expansion works
  expect_equal(
    expand_inputs(file.path(dirname, 'sauciss*')),
    files
  )

  # Error is thrown if no files match glob
  expect_error(
    expand_inputs(file.path(dirname, 'sauce*'))
  )

  # Unless we tell it not to check existence
  expect_equal(
    expand_inputs(file.path(dirname, 'sauce*'), check_exists=FALSE),
    as.character(c())
  )

  # Expansion can also be disabled
  expect_equal(
    expand_inputs(file.path(dirname, 'sauce*'), check_exists=FALSE, expand_globs=FALSE),
    file.path(dirname, 'sauce*')
  )

})
