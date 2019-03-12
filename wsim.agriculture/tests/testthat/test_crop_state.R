context('crop state')

test_that('correct state changes computed: middle of year, summer growth', {
  month          <- 4
  days_in_month  <- 30
  gd   <- list(this_year=15,  next_year=0)
  loss <- list(this_year=0.4, next_year=0)
  
  state <- list(
    loss_days_current_year = 5,
    loss_days_next_year = 0,
    fraction_remaining_current_year = 0.9,
    fraction_remaining_next_year    = 1.0
  ) 
  
  next_state <- update_crop_state(state, gd, days_in_month, loss, month==1, winter_growth=FALSE) 
  
  expect_equal(next_state$loss_days_current_year, 5+0.4*15)
  expect_equal(next_state$loss_days_next_year, 0)
  
  expect_equal(next_state$fraction_remaining_current_year, 0.9*(1 - 0.4*15/30))
  expect_equal(next_state$fraction_remaining_next_year, 1)
})

test_that('correct state changes computed: start of year, summer growth', {
  month          <- 1
  days_in_month  <- 30
  loss           <- list(this_year=0.4, next_year=0)
  gd             <- list(this_year=15,  next_year=0)
  
  state <- list(
    loss_days_current_year = 5,
    loss_days_next_year = 0,
    fraction_remaining_current_year = 0.4,
    fraction_remaining_next_year = 1.0
  ) 
  
  next_state <- update_crop_state(state, gd, days_in_month, loss, month==1, winter_growth=FALSE) 
  
  expect_equal(next_state$loss_days_current_year, 0.4*15)
  expect_equal(next_state$loss_days_next_year, 0)
  
  expect_equal(next_state$fraction_remaining_current_year, 1 - 0.4*15/30)
  expect_equal(next_state$fraction_remaining_next_year, 1)
})

test_that('correct state changes computed: start of year, winter growth', {
  month          <- 1
  days_in_month  <- 30
  loss           <- list(this_year=0.6, next_year=0.3)
  gd             <- list(this_year=17,  next_year=8)
  
  state <- list(
    loss_days_current_year = 5,
    loss_days_next_year = 102,
    fraction_remaining_current_year = 0.4,
    fraction_remaining_next_year = 0.5
  ) 
  
  next_state <- update_crop_state(state, gd, days_in_month, loss, month==1, winter_growth=TRUE) 
  
  expect_equal(next_state$loss_days_current_year, 102 + 0.6*17)
  expect_equal(next_state$loss_days_next_year, 0.3*8)
  
  expect_equal(next_state$fraction_remaining_current_year, 0.5*(1 - 0.6*17/30))
  expect_equal(next_state$fraction_remaining_next_year, 1 - 0.3*8/30)
})
