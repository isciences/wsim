#' Update the state variables for a single crop
#' 
#' @param state          crop state object, with
#'                       \itemize{
#'                         \item loss_days_current_year
#'                         \item loss_days_next_year
#'                         \item fraction_remaining_current_year
#'                         \item fraction_remaining_next_year
#'                       }
#' @param gd             number of growing days in current month (varies by pixel)
#' @param days_in_month  scalar number of days in month
#' @param loss           loss vectors for this timestep
#' @param reset          reset input state (e.g., January 1)
#' @param winter_growth  boolean - does this crop grow over the winter?
#' @param initial_fraction_remaining pixelwise initial fraction remaining at start of growing season
#' @return list with updated \code{loss_days} and \code{frac_remaining}
#' 
#' @export
update_crop_state <- function(state,
                              gd,
                              days_in_month,
                              loss,
                              reset,
                              winter_growth,
                              initial_fraction_remaining) {
  
  if (reset) {
    next_state <- list(
      # For winter-grown crops, carry loss days from previous year to this year
      # For summer-grown crops, reset loss days to zero
      loss_days_current_year= ifelse(winter_growth, state$loss_days_next_year, 0) + loss*gd$this_year,
      
      # In both cases, reset next year's loss to zero
      loss_days_next_year= state$loss_days_next_year*0 + loss*gd$next_year,
      
      # Similarly, either carry forward the crop fraction remaining, or set it to 100%
      fraction_remaining_current_year= ifelse(winter_growth, state$fraction_remaining_next_year, initial_fraction_remaining)*(1-loss*gd$this_year/days_in_month),
      fraction_remaining_next_year= initial_fraction_remaining*(1-loss*gd$next_year/days_in_month) # create array w/same dims as winter_growth
    )
  } else {
    next_state <- list(
      loss_days_current_year= state$loss_days_current_year + loss*gd$this_year,
      loss_days_next_year= state$loss_days_next_year + loss*gd$next_year,
      fraction_remaining_current_year= state$fraction_remaining_current_year*(1 - loss*gd$this_year/days_in_month),
      fraction_remaining_next_year=    state$fraction_remaining_next_year*(1 - loss*gd$next_year/days_in_month)
    )
  }
  
  # postcondition checks
  
  # state variables are defined wherever growing days are
  stopifnot(all(is.na(gd$this_year) == is.na(next_state$fraction_remaining_current_year)))
  stopifnot(all(is.na(gd$next_year) == is.na(next_state$fraction_remaining_next_year)))
  stopifnot(all(is.na(gd$this_year) == is.na(next_state$loss_days_current_year)))
  stopifnot(all(is.na(gd$next_year) == is.na(next_state$loss_days_next_year)))
   
  return(next_state)
}
