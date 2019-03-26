#' Elementwise summation of two matrices, disaggregating one matrix if needed
#' 
#' @param a a matrix
#' @param b a matrix whose dimensions are an integer multiple of \code{a}'s
#' @param na.rm If true, treats \code{NA} as zero in summation, except for
#'              the case of \code{NA+NA}, which remains equal to \code{NA}.
#' @export
psum <- function(a, b, na.rm=FALSE) {
  disaggregate_pfun(a, b, 'sum', na.rm)  
}

#' Elementwise product of two matrices, disaggregating one matrix if neeeded
#' 
#' @export
pprod <- function(a, b) {
  disaggregate_pfun(a, b, 'product', FALSE)  
}