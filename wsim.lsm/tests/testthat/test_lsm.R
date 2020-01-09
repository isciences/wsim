# Copyright (c) 2018-2020 ISciences, LLC.
# All rights reserved.
#
# WSIM is licensed under the Apache License, Version 2.0 (the "License").
# You may not use this file except in compliance with the License. You may
# obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0.
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require(testthat)

context('LSM functions')

RANDOM_TRIALS <- 100

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
  expect_equal(0.77, sum(make_daily_precip(0.77, 28, 1e-3)));
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
    flow_directions=matrix(rep.int(as.integer(NA), 4), nrow=2),
    Wc=matrix(rep.int(150, 4), nrow=2)
  )

  forcing <- make_forcing(
    extent=c(-180, 180, -90, 90),
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

test_that('mass is conserved in daily hydro calculations', {
  for (i in seq_len(RANDOM_TRIALS)) {
    P <- 0
    Sa <- 0
    Sm <- 0

    precip <- rbinom(1, 1, prob=0.5)
    if (precip) {
      P <- runif(1, min=0, max=100)
    }

    snow_accum <- rbinom(1, 1, prob=0.5)
    if (snow_accum) {
      Sa <- runif(1)*P  # some fraction of precip accumulates as snow
    } else {
      snow_melt <- rbinom(1, 1, prob=0.5)
      if (snow_melt) {
        Sm <- runif(1, min=0, max=10) # generate some snowmelt in addition to any precip
      }
    }

    E0 <- runif(1, min=0, max=100)
    Wc <- runif(1, min=0, max=300)
    Ws <- runif(1)*Wc

    nDays <- runif(1, min=1, max=40)
    pWetDays <- runif(1)

    hydro <- daily_hydro(P, Sa, Sm, E0, Ws, Wc, nDays, pWetDays)

    mass_in <- P - Sa + Sm
    mass_out <- hydro$E + hydro$R

    expect_equal(mass_in - mass_out, hydro$dWdt)
  }
})

test_that('mass is conserved in runoff detention', {
  set.seed(456)
  for (i in seq_len(RANDOM_TRIALS)) {
    precip_falls <- rbinom(1, 1, 0.5)

    if (precip_falls) {
      Pr <- runif(1, min=0, max=40)
    } else {
      Pr <- 0
    }

    snow_melts <- rbinom(1, 1, 0.3)
    if (snow_melts) {
      Sm <- runif(1, min=0, max=40)
      melt_month <- sample(1:4, 1)
      Sa <- 0
    } else {
      Sm <- 0
      melt_month <- 0

      snow_accumulates <- rbinom(1, 1, 0.3)
      if (snow_accumulates) {
        Sa <- Pr #runif(1)*Pr
      } else {
        Sa <- 0
      }
    }

    detained_runoff <- rbinom(1, 1, 0.8)
    if (detained_runoff) {
      Dr <- runif(1, min=0, max=100)
    } else {
      Dr <- 0
    }

    detained_snowmelt <- rbinom(1, 1, 0.3)
    if (detained_snowmelt) {
      Ds <- runif(1, min=0, max=100)
    } else {
      Ds <- 0
    }

    elevation <- runif(1, min=0, max=1000)

    if ((precip_falls || snow_melts) && !snow_accumulates) {
      runoff_produced <- rbinom(1, 1, 0.8)

      if (runoff_produced) {
        R <- runif(1)*(Pr + Sm)
      } else {
        R <- 0
      }
    } else {
      R <- 0
    }

    P <- Pr + Sm - Sa

    detained <- calc_detained(R, Pr, P, Sm, Dr, Ds, elevation, melt_month)

    initial_mass <- Dr + Ds
    final_mass <- (Ds + detained$dDsdt) + (Dr + detained$dDrdt)

    mass_in <- R
    mass_out <- detained$Rp + detained$Rs

    expect_equal(mass_in - mass_out, final_mass - initial_mass)
  }
})
