% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/RcppExports.R
\name{stack_max}
\alias{stack_max}
\title{Compute the maximum defined element for each row and col in a 3D array}
\usage{
stack_max(v)
}
\arguments{
\item{v}{3D array that may contain NA values}
}
\value{
a matrix with the maximum value for each [row, col, ]
}
\description{
Returned value is indexed beginning at 1
}
