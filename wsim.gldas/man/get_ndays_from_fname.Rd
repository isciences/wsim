% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/get_ndays_from_filename.R
\name{get_ndays_from_fname}
\alias{get_ndays_from_fname}
\title{Read a raster filename, extract a date in yyyymm format if it's contained in the filename, and return the number of days in the month mm.
Note that this does not take leap years into account, i.e. 28 is always returned for month 02.}
\usage{
get_ndays_from_fname(raster_fname)
}
\arguments{
\item{raster_fname}{A character string representing a filename.}
}
\value{
An integer of the number of days in the month component of the extracted yyyymm
examples
get_ndays_from_fname('~/Documents/wsim/source/GLDAS_NOAH025_M.A194801.020.nc4')
}
\description{
This is because WSIM uses on monthly sums and averages as the lowest temporal unit of its variables,
and we determine, e.g., monthly precipitation, by aggregating an average rate up by the number of days in the month.
If we were to compare precipitation between a 29-day February and a series of 28-day Februaries,
the 29-day February may look anomalous merely by comprising one more day of average rainfall than the other Februaries.
}
