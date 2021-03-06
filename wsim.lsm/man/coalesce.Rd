% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/RcppExports.R
\name{coalesce}
\alias{coalesce}
\title{Replace NA values with a specified constant}
\usage{
coalesce(v, replacement_value)
}
\arguments{
\item{v}{a numeric vector that may
contain NA values}

\item{replacement_value}{a constant with with NA values
should be replaced}
}
\value{
a copy of \code{v} with NA values replaced by
        \code{replacement_value}
}
\description{
Replace NA values with a specified constant
}
