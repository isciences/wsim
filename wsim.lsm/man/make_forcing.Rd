% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/lsm_forcing.R
\name{make_forcing}
\alias{make_forcing}
\title{Make a WSIM LSM forcing}
\usage{
make_forcing(extent, pWetDays, T, Pr)
}
\arguments{
\item{extent}{spatial extent of input matrices \code{(xmin, xmax, ymin, ymax)}}

\item{pWetDays}{Percentage of days in which precipitation falls [-]}

\item{T}{Temperature [degrees C]}

\item{Pr}{Precipitation [mm]}
}
\value{
\code{wsim.lsm.forcing} object containing supplied variables
}
\description{
Make a WSIM LSM forcing
}
