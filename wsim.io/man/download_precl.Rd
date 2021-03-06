% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/read_noaa_precl.R
\name{download_precl}
\alias{download_precl}
\title{Download a month of PREC/L precipitation data and write to netCDF}
\usage{
download_precl(fname, year, month, what = "precipitation_rate")
}
\arguments{
\item{fname}{of output filename}

\item{year}{year to download}

\item{month}{month to download}

\item{what}{\code{precipitation_rate} or \code{gauge_count}}
}
\description{
Download a month of PREC/L precipitation data and write to netCDF
}
