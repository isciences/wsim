#' @export
error <- function(...) {
  futile.logger::flog.error(paste0(list(...), collapse=' '))
}

#' @export
fatal <- function(...) {
  futile.logger::flog.fatal(paste0(list(...), collapse=' '))
}

#' @export
info <- function(...) {
  futile.logger::flog.info(paste0(list(...), collapse=' '))
}

#' @export
warn <- function(...) {
  futile.logger::flog.warn(paste(list(...), collapse=' '))
}

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
