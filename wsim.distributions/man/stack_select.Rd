% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/RcppExports.R
\name{stack_select}
\alias{stack_select}
\title{Extract a slab of n elements from an array, with a variable starting point}
\usage{
stack_select(v, start, n, fill)
}
\arguments{
\item{v}{a three-dimemsional array}

\item{start}{a matrix containing start indices along the third dimension of \code{v}}

\item{n}{the number of elements to extract along the third dimension}

\item{fill}{a fill value to use where \code{start[i, j] < 1 | start[i, j] + n > dim(v)[3]},
or a function taking no arguments that will be called to obtain fill values}
}
\description{
Extract a slab of n elements from an array, with a variable starting point
}
