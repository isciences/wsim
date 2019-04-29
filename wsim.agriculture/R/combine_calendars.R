#' Combine multiple crop calendars
#' 
#' Combine a primary calendar with one or more supplementary calendars.
#' Supplementary calendars are used to augument the primary calendar when
#' the primary calendar contains no data for a given subcrop. Supplementary
#' calendars are considered in the order they are passed to \code{combine_calendars}.
#' 
#' @param ... one or more crop calendars
#' @return    a crop calendar that contains data for all subcrops that are represented
#'            in any of the provided calendars
#' @export
combine_calendars <- function(...) {
  calendars <- list(...)
  
  calendar <- calendars[[1]]
  for (alternate_calendar in calendars[-1]) {
    calendar <- rbind(calendar,
                      dplyr::anti_join(alternate_calendar, calendar, by=c('unit_code', 'crop')))
  }
  
  return(calendar)
}