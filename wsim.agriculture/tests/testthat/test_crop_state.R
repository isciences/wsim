context('crop state')

test_that('correct state changes computed: middle of year, summer growth', {
  month          <- 4
  days_in_month  <- 30
  gd   <- list(this_year=15,  next_year=0)
  loss <- 0.4
  
  state <- list(
    loss_days_current_year = 5,
    loss_days_next_year = 0,
    fraction_remaining_current_year = 0.9,
    fraction_remaining_next_year    = 1.0
  ) 
  
  next_state <- update_crop_state(state, gd, days_in_month, loss, month==1, winter_growth=FALSE, initial_fraction_remaining=1) 
  
  expect_equal(next_state$loss_days_current_year, 5+0.4*15)
  expect_equal(next_state$loss_days_next_year, 0)
  
  expect_equal(next_state$fraction_remaining_current_year, 0.9*(1 - 0.4*15/30))
  expect_equal(next_state$fraction_remaining_next_year, 1)
})

test_that('correct state changes computed: start of year, summer growth', {
  month          <- 1
  days_in_month  <- 30
  loss           <- 0.4
  gd             <- list(this_year=15,  next_year=0)
  
  state <- list(
    loss_days_current_year = 5,
    loss_days_next_year = 0,
    fraction_remaining_current_year = 0.4,
    fraction_remaining_next_year = 1.0
  ) 
  
  next_state <- update_crop_state(state, gd, days_in_month, loss, month==1, winter_growth=FALSE, initial_fraction_remaining=1.0) 
  
  expect_equal(next_state$loss_days_current_year, 0.4*15)
  expect_equal(next_state$loss_days_next_year, 0)
  
  expect_equal(next_state$fraction_remaining_current_year, 1 - 0.4*15/30)
  expect_equal(next_state$fraction_remaining_next_year, 1)
})

test_that('correct state changes computed: start of year, winter growth', {
  month          <- 1
  days_in_month  <- 30
  loss           <- 0.6
  gd             <- list(this_year=17,  next_year=8)
  
  state <- list(
    loss_days_current_year = 5,
    loss_days_next_year = 102,
    fraction_remaining_current_year = 0.4,
    fraction_remaining_next_year = 0.5
  ) 
  
  next_state <- update_crop_state(state, gd, days_in_month, loss, month==1, winter_growth=TRUE, initial_fraction_remaining=1.0) 
  
  expect_equal(next_state$loss_days_current_year, 102 + 0.6*17)
  expect_equal(next_state$loss_days_next_year, 0.6*8)
  
  expect_equal(next_state$fraction_remaining_current_year, 0.5*(1 - 0.6*17/30))
  expect_equal(next_state$fraction_remaining_next_year, 1 - 0.6*8/30)
})

test_that('initial fraction remaining handled properly', {
  month <- 1
  days_in_month <- 30
  loss <- 0
  gd <- list(this_year=30, next_year=0)
  
  state <-
    list(loss_days_current_year= array(20, dim=c(3,4)),
         loss_days_next_year= array(0, dim=c(3,4)),
         fraction_remaining_current_year= array(0, dim=c(3,4)),
         fraction_remaining_next_year= array(0, dim=c(3,4)))
  
  ifrac <- array(0.5 + seq(from=0, by=0.1, length.out=12), dim=c(3,4))
  
  next_state <- update_crop_state(state, gd, days_in_month, loss, month==1, winter_growth=array(FALSE, dim=c(3,4)), initial_fraction_remaining=ifrac)
  
  expect_equal(next_state$fraction_remaining_current_year, ifrac)
  expect_equal(next_state$fraction_remaining_next_year, ifrac)
})
