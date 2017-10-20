require(testthat)

context("Forecast bias-correction")

correct <- function(distribution, value, retro_fit, obs_fit) {
  do.call(gev_forecast_correct, unname(c(lapply(c(value, obs_fit, retro_fit), matrix), list(100, 0.5))))[1,1]
}

test_that('we can bias-correct a value', {
  obs <- c(location= -13.42731,
             scale= 3.696941,
             shape= 0.3767407)

  retro <- c(location=-20.58498,
           scale=4.040313,
           shape=0.2958461)

  val <- -26.11339

  corrected <- correct('gev', val, retro, obs)

  expect_equal(corrected, -18.74234, tolerance=1e-3)
})
