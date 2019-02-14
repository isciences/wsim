# Copyright (c) 2018 ISciences, LLC.
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

#' Strip trailing newline characters from text
#' @param text text to strip
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

#' Format and generate a log message at the \code{ERROR} level
#'
#' @param msg A message to log. May be a format string.
#' @param ... Arguments to fill placeholders in format string
#'
#' @export
errorf <- function(msg, ...) {
  futile.logger::flog.error(msg, ...)
}

#' Generate a log message at the \code{FATAL} level
#'
#' @param ... Any number of string-convertible objects
#'
#' @export
fatal <- function(...) {
  futile.logger::flog.fatal(strip(paste(lapply(list(...), toString), collapse=' ')))
}

#' Format and generate a log message at the \code{FATAL} level
#'
#' @param msg A message to log. May be a format string.
#' @param ... Arguments to fill placeholders in format string
#'
#' @export
fatalf <- function(msg, ...) {
  futile.logger::flog.fatal(msg, ...)
}

#' Generate a log message at the \code{INFO} level
#'
#' @param ... Any number of string-convertible objects
#'
#' @export
info <- function(...) {
  futile.logger::flog.info(strip(paste(lapply(list(...), toString), collapse=' ')))
}

#' Format and generate a log message at the \code{INFO} level
#'
#' @param msg A message to log. May be a format string.
#' @param ... Arguments to fill placeholders in format string
#'
#' @export
infof <- function(msg, ...) {
  futile.logger::flog.info(msg, ...)
}

#' Generate a log message at the \code{WARN} level
#'
#' @param ... Any number of string-convertible objects
#'
#' @export
warn <- function(...) {
  futile.logger::flog.warn(strip(paste(lapply(list(...), toString), collapse=' ')))
}

#' Format and generate a log message at the \code{WARN} level
#'
#' @param msg A message to log. May be a format string.
#' @param ... Arguments to fill placeholders in format string
#'
#' @export
warnf <- function(msg, ...) {
  futile.logger::flog.warn(msg, ...)
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
