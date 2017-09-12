require(testthat)

context("Command-line argument parsing")

test_that("argument values can be type-coerced", {
  usage <- "Usage: my_program.R --status=<status> --cats=<num_cats>"
  args <- list("--cats=3", "--status=unknown")

  parsed <- parse_args(usage, args, list(cats="integer"))

  expect_equal(parsed$cats, 3)
})
