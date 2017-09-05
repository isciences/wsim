require(testthat)

context('LSM functions')

test_that('all precip accumulates as snow when temp < -1 C', {
  expect_equal(3.2, snow_accum(3.2, -5))
})

test_that('no precip accumulates as snow when temp > -1 C', {
  expect_equal(0.0, snow_accum(3.2, 0.0))
})

test_that('no precip accumulates as snow when temp is unknown', {
  expect_equal(0.0, snow_accum(3.2, NA))
})

test_that('no snowmelt if temp < -1 C', {
  args <- list(
    snowpack = 20,
    melt_month = 0,
    T = -2,
    z = 520
  )
  expect_equal(0.0, do.call(snow_melt, args))
})

test_that('no snowmelt if elevation undefined', {
  args <- list(
    snowpack = 20,
    melt_month = 0,
    T = 20,
    z = NA
  )
  expect_true(is.na(do.call(snow_melt, args)))
})

test_that('no snowmelt if melt_month undefined', {
  args <- list(
    snowpack = 20,
    melt_month = NA,
    T = 20,
    z = 520
  )
  expect_true(is.na(do.call(snow_melt, args)))
})

test_that('all snow melts if elev < 500', {
  args <- list(
    snowpack = 20,
    melt_month = 0,
    T = 2,
    z = 499
  )
  expect_equal(20, do.call(snow_melt, args))

  args <- list(
    snowpack = 20,
    melt_month = 1,
    T = 2,
    z = 499
  )
  expect_equal(20, do.call(snow_melt, args))
})

test_that('above 500 m elev, snowmelt depends on melt month', {
  args <- list(
    snowpack = 20,
    melt_month = 1,
    T = 2,
    z = 501
  )
  expect_equal(10, do.call(snow_melt, args))

  args <- list(
    snowpack = 20,
    melt_month = 2,
    T = 2,
    z = 501
  )
  expect_equal(20, do.call(snow_melt, args))
})

test_that('daily precip is returned for the correct number of days', {
  expect_equal(13, length(make_daily_precip(0.77, 13, 1.0)));
  expect_equal(13, length(make_daily_precip(0.77, 13, 0.7)));
  expect_equal(13, length(make_daily_precip(0.77, 13, 0.0)));
})

test_that('daily precipitation adds up to monthly precipitation', {
  expect_equal(0.77, sum(make_daily_precip(0.77, 13, 1.0)));
  expect_equal(0.77, sum(make_daily_precip(0.77, 13, 0.7)));
  expect_equal(0.77, sum(make_daily_precip(0.77, 30, 0.0)));
})

test_that('excess precipitation fills soil to capacity', {
  Ws <- 0.3
  Wc <- 0.5
  P <- 1
  E0 <- 0.7

  expect_equal(Wc, Ws + soil_moisture_change(P, E0, Ws, Wc))
})

test_that('all extra precipitation is absorbed by soil', {
  Ws <- 0.3
  Wc <- 0.5
  P <- 1
  E0 <- 0.9

  expect_equal(P-E0, soil_moisture_change(P, E0, Ws, Wc))
})

test_that('when there is not enough precipitation, the soil dries up to 90%', {
  Ws <- 0.3
  Wc <- 0.5
  P <- 1
  E0 <- 1.1

  # Compute drying according to our drying functions
  expect_equal(-0.0835, soil_moisture_change(P, E0, Ws, Wc), tolerance=1e-4)

  E0 <- 2
  # Severe precipitation deficit.  Hit our 90% cap on drying
  expect_equal(-0.27, soil_moisture_change(P, E0, Ws, Wc))

})

test_that('computed state variables are always defined', {
  static <- list(
    elevation=matrix(seq(0, 750, 250), nrow=2),
    area_m2=matrix(rep.int(100, 4), nrow=2),
    flow_directions=matrix(rep.int(as.integer(NA), 4), nrow=2),
    Wc=matrix(rep.int(150, 4), nrow=2)
  )

  forcing <- list(
    daylength=matrix(seq(0, 1, 1/3), nrow=2),
    pWetDays=matrix(rep.int(1, 4), nrow=2),
    T=matrix(rep.int(NA, 4), nrow=2),
    Pr=matrix(runif(4), nrow=2),
    nDays=30
  )

  state <- list(
    Snowpack= matrix(runif(4), nrow=2),
    Dr= matrix(runif(4), nrow=2),
    Ds= matrix(runif(4), nrow=2),
    melt_month= matrix(rep.int(0, 4), nrow=2),
    Ws= static$Wc * runif(1)
  )

  iter <- run(static, state, forcing)
  expect_false(any(is.na(iter$next_state$Snowpack)))
  expect_false(any(is.na(iter$next_state$Dr)))
  expect_false(any(is.na(iter$next_state$Ds)))
  expect_false(any(is.na(iter$next_state$Ws)))
})

test_that('dWdt calculation tolerates NODATA inputs', {
  P  <- 9.95522403717041
  Sa <- 0
  Sm <- as.numeric(NA)
  E0 <- 94.36259460449219
  Ws <- 27.140303302177646
  Wc <- 42
  nDays <- 30
  pWetDays <- 0.100000001490116

  hydro <- daily_hydro(P, Sa, Sm, E0, Ws, Wc, nDays, pWetDays)

  expect_false(is.na(hydro$dWdt))
})

test_that('cell areas are computed correctly', {
  empty_hlf_deg <- raster::raster(nrows=360, ncols=720, xmn=-180, xmx=180, ymn=-90, ymx=90)
  area_hlf_deg <- cell_areas_m2(empty_hlf_deg)

  expect_equal(unname(area_hlf_deg[108, 17]), 2498.256e6)
})
