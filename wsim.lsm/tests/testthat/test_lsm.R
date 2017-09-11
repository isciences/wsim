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

  forcing <- make_forcing(
    extent=c(-180, 180, -90, 90),
    daylength=matrix(seq(0, 1, 1/3), nrow=2),
    pWetDays=matrix(rep.int(1, 4), nrow=2),
    T=matrix(rep.int(NA, 4), nrow=2),
    Pr=matrix(runif(4), nrow=2)
  )

  state <- make_state(
    extent=c(-180, 180, -90, 90),
    Snowpack= matrix(runif(4), nrow=2),
    Dr= matrix(runif(4), nrow=2),
    Ds= matrix(runif(4), nrow=2),
    snowmelt_month= matrix(rep.int(0, 4), nrow=2),
    Ws= static$Wc * runif(1),
    yearmon='201609'
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

test_that('date calculations are correct', {
  expect_equal(next_yyyymm('201612'), '201701')
  expect_equal(next_yyyymm('201701'), '201702')

  expect_equal(days_in_yyyymm('201701'), 31)
  expect_equal(days_in_yyyymm('201702'), 28)
  expect_equal(days_in_yyyymm('201602'), 29)
})

test_that('we can read and write states from/to netCDF', {
  fname <- tempfile()

  state <- make_state(
    extent=c(-180, 180, -90, 90),
    Snowpack= matrix(runif(4), nrow=2),
    Dr= matrix(runif(4), nrow=2),
    Ds= matrix(runif(4), nrow=2),
    snowmelt_month= matrix(rep.int(0, 4), nrow=2),
    Ws= matrix(runif(4), nrow=2),
    yearmon='201609'
  )

  write_lsm_values_to_cdf(state, fname, cdf_attrs)
  expect_true(file.exists(fname))

  state2 <- read_state_from_cdf(fname)
  expect_equal(state2, state, check.attributes=FALSE)

  file.remove(fname)
})

test_that('we can read forcing from netCDF', {
  fname <- tempfile()

  forcing <- make_forcing(
    extent=c(-180, 180, -90, 90),
    daylength=matrix(seq(0, 1, 1/3), nrow=2),
    pWetDays=matrix(rep.int(1, 4), nrow=2),
    T=matrix(rep.int(NA, 4), nrow=2),
    Pr=matrix(runif(4), nrow=2)
  )

  wsim.lsm::write_lsm_values_to_cdf(forcing, fname, wsim.lsm::cdf_attrs)
  forcing2 <- read_forcing_from_cdf(fname)

  expect_equal(forcing2, forcing, check.attributes=FALSE)

  file.remove(fname)
})

test_that('we can write model results to netCDF', {
  static <- list(
    elevation=matrix(seq(0, 800, 100), nrow=3),
    area_m2=matrix(rep.int(100, 9), nrow=3),
    flow_directions=matrix(rep.int(as.integer(NA), 9), nrow=3),
    Wc=matrix(rep.int(150, 9), nrow=3)
  )

  forcing <- make_forcing(
    extent=c(-180, 180, -90, 90),
    daylength=matrix(seq(0, 1, 1/8), nrow=3),
    pWetDays=matrix(rep.int(1, 9), nrow=3),
    T=matrix(runif(9), nrow=3),
    Pr=matrix(runif(9), nrow=3)
  )

  state <- make_state(
    extent=c(-180, 180, -90, 90),
    Snowpack= matrix(runif(9), nrow=3),
    Dr= matrix(runif(9), nrow=3),
    Ds= matrix(runif(9), nrow=3),
    snowmelt_month= matrix(rep.int(0, 9), nrow=3),
    Ws= static$Wc * runif(1),
    yearmon='201609'
  )

  iter <- wsim.lsm::run(static, state, forcing)

  fname <- tempfile()
  wsim.lsm::write_lsm_values_to_cdf(iter$obs, fname, wsim.lsm::cdf_attrs)
  file.remove(fname)
})