require(testthat)

context("Forecast bias-correction")

correct <- function(distribution, value, retro_fit, obs_fit) {
  do.call(gev_forecast_correct, unname(c(lapply(c(value, obs_fit, retro_fit), matrix), list(100, 0.5))))[1,1]
}

test_that('when observed and retospective forecast distributions are defined, we can
           bias-correct a forecast by looking up the observed value corresponding to
           the quantile of the forecast value relative to the retrospective
           distribution', {

  obs <- c(location= -13.42731,
           scale= 3.696941,
           shape= 0.3767407)

  retro <- c(location= -20.58498,
             scale= 4.040313,
             shape= 0.2958461)

  val <- -26.11339

  corrected <- correct('gev', val, retro, obs)

  expect_equal(corrected, -18.74234, tolerance=1e-3)
})

test_that('if the observed location value is unknown, the corrected value is undefined', {

  obs <- c(location= NA,
           scale= 3.696941,
           shape= 0.3767407)

  retro <- c(location= -20.58498,
             scale= 4.040313,
             shape= 0.2958461)

  val <- -26.11339

  corrected <- correct('gev', val, retro, obs)

  expect_na(corrected)
})

test_that('if the observed location value is known, but the other distribution parameters are not,
           then the corrected value is the observed location value', {

  obs <- c(location= 0.1,
           scale= NA,
           shape= NA)

  retro <- c(location= 0.4101557,
             scale= 0.6777912,
             shape= -0.5597312)

  for (val in runif(3)) {
    corrected <- correct('gev', val, retro, obs)

    expect_equal(corrected, obs['location'], check.attributes=FALSE)
  }

})

test_that('if any component of the retrospective forecast distribution is undefined,
           then the corrected value is the median of the observed values', {

  obs <- c(location= -13.42731,
           scale= 3.696941,
           shape= 0.3767407)

  retro <- c(location= -20.58498,
             scale= NA,
             shape= 0.2958461)

  for (val in runif(3)) {
    corrected <- correct('gev', val, retro, obs)

    expect_equal(corrected, lmom::quagev(0.5, obs), check.attributes=FALSE)
  }

})
