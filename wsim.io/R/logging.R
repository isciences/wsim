#' Strip trailing newline characters from text
strip <- function(text) {
  gsub('[\r\n]*$', '', text)
}

#' Generate a log message at the \code{ERROR} level
#'
#' @param ... Any number of string-convertible objects
#'
#' @export
error <- function(...) {
  futile.logger::flog.error(strip(paste(lapply(list(...), toString), collapse=' ')))
}

#' Generate a log message at the \code{FATAL} level
#'
#' @param ... Any number of string-convertible objects
#'
#' @export
fatal <- function(...) {
  futile.logger::flog.fatal(strip(paste(lapply(list(...), toString), collapse=' ')))
}

#' Generate a log message at the \code{INFO} level
#'
#' @param ... Any number of string-convertible objects
#'
#' @export
info <- function(...) {
  futile.logger::flog.info(strip(paste(lapply(list(...), toString), collapse=' ')))
}

#' Generate a log message at the \code{WARN} level
#'
#' @param ... Any number of string-convertible objects
#'
#' @export
warn <- function(...) {
  futile.logger::flog.warn(strip(paste(lapply(list(...), toString), collapse=' ')))
}

#' Initialize logging functionality
#'
#' Initializes logging at the level set in the environment
#' variable \code{WSIM_LOGGING}. Calling this function be
#' the first thing any WSIM program does.
#'
#' @param tool_name Name of the program, to be used in
#'                  formatting log messages
#'
#' @export
logging_init <- function(tool_name) {
  level <- tolower(Sys.getenv('WSIM_LOGGING', 'INFO'))

  flevel <- switch(level,
                  error= futile.logger::ERROR,
                  warn=  futile.logger::WARN,
                  fatal= futile.logger::FATAL,
                  info=  futile.logger::INFO,
                  futile.logger::DEBUG
  )

  ok<-futile.logger::flog.threshold(flevel)
  ok<-futile.logger::flog.layout(futile.logger::layout.format(paste0(tool_name, ' [~l]: ~t ~m')))
}
