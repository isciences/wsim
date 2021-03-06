% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/parse_args.R
\name{parse_args}
\alias{parse_args}
\title{Parse command-line arguments from a docopt string}
\usage{
parse_args(usage, args = commandArgs(TRUE), types = list())
}
\arguments{
\item{usage}{a docopt string describing program usage}

\item{args}{a list of command-line arguments}

\item{types}{an optional list of types to which specific
arguments should be coerced, e.g. \code{list(num_cores="integer")}}
}
\value{
a list of parsed arguments
}
\description{
If specified arguments are not valid, this function will
print the usage information and exit the program with
status=1.
}
