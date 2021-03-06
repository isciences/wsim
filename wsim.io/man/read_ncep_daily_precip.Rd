% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/read_ncep_daily_precip.R
\name{read_ncep_daily_precip}
\alias{read_ncep_daily_precip}
\title{Read GrADS file containing NCEP global precipitation}
\usage{
read_ncep_daily_precip(fname, mv = -999, layer = 1)
}
\arguments{
\item{fname}{filename to read}

\item{mv}{NODATA value}

\item{layer}{layer to retrieve (1 = precipitation rates, 2 = number of stations)}
}
\value{
a matrix of daily precipitation values in 0.1 mm/day
}
\description{
Reads an 0.5-degree daily precipitation file produced by the CPC
Gauge-Based Analysis of Global Daily Precipitation project, as described at
ftp://ftp.cpc.ncep.noaa.gov/precip/CPC_UNI_PRCP/GAUGE_GLB/DOCU/PRCP_CU_GAUGE_V1.0GLB_0.50deg_README.txt
}
\details{
The files are in a GrADS format.  URL to download an example file:
ftp://ftp.cpc.ncep.noaa.gov/precip/CPC_UNI_PRCP/GAUGE_GLB/RT/2017/
}
