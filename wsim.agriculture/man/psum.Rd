% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/psum.R
\name{psum}
\alias{psum}
\title{Elementwise summation of two matrices, disaggregating one matrix if needed}
\usage{
psum(a, b, na.rm = FALSE)
}
\arguments{
\item{a}{a matrix}

\item{b}{a matrix whose dimensions are an integer multiple of \code{a}'s}

\item{na.rm}{If true, treats \code{NA} as zero in summation, except for
the case of \code{NA+NA}, which remains equal to \code{NA}.}
}
\value{
a+b
}
\description{
Elementwise summation of two matrices, disaggregating one matrix if needed
}
