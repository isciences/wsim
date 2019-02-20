#' Combine multiple crop calendars
#' 
#' @param ... one or more crop calendars
#' @return a combination of them
#' @export
combine_calendars <- function(...) {
  calendars <- list(...)
  
  calendar <- calendars[[1]]
  for (alternate_calendar in calendars[-1]) {
    calendar <- rbind(calendar,
                      alternate_calendar %>% 
                        dplyr::anti_join(calendar, by=c('unit_code', 'crop')))
  }
  
  return(calendar)
}