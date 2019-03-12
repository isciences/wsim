#' Update the state variables for a single crop
#' 
#' @param state          crop state object, with
#'                       - loss_days_current_year
#'                       - loss_days_next_year
#'                       - fraction_remaining_current_year
#'                       - fraction_remaining_next_year
#' @param gd             number of growing days in current month (varies by pixel)
#' @param days_in_month  scalar number of days in month
#' @param loss           list of loss vectors for this timestep (names=this_year, next_year)
#' @param reset          reset input state (e.g., January 1)
#' @param winter_growth  boolean - does this crop grow over the winter?
#' @return list with updated \code{loss_days} and \code{frac_remaining}
#' 
#' @export
update_crop_state <- function(state,
                              gd,
                              days_in_month,
                              loss,
                              reset,
                              winter_growth) {
  
  if (reset) {
    return(list(
      # For winter-grown crops, carry loss days from previous year to this year
      # For summer-grown crops, reset loss days to zero
      loss_days_current_year= ifelse(winter_growth, state$loss_days_next_year, 0) + loss$this_year*gd$this_year,
      
      # In both cases, reset next year's loss to zero
      loss_days_next_year= state$loss_days_next_year*0 + loss$next_year*gd$next_year,
      
      # Similarly, either carry forward the crop fraction remaining, or set it to 100%
      fraction_remaining_current_year= ifelse(winter_growth, state$fraction_remaining_next_year, 1.0)*(1-loss$this_year*gd$this_year/days_in_month),
      fraction_remaining_next_year= (winter_growth*0 + 1)*(1-loss$next_year*gd$next_year/days_in_month) # create array w/same dims as winter_growth
    ))
  }
  
  return(list(
    loss_days_current_year= state$loss_days_current_year + loss$this_year*gd$this_year,
    loss_days_next_year= state$loss_days_next_year + loss$next_year*gd$next_year,
    fraction_remaining_current_year= state$fraction_remaining_current_year*(1 - loss$this_year*gd$this_year/days_in_month),
    fraction_remaining_next_year=    state$fraction_remaining_next_year*(1 - loss$next_year*gd$next_year/days_in_month)
  ))
}
