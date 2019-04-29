.onLoad <- function(libname, pkgname) {
  utils::data("wsim_crop_codes",  package=pkgname, envir=parent.env(environment()))
  utils::data("mirca_crop_codes", package=pkgname, envir=parent.env(environment()))
}