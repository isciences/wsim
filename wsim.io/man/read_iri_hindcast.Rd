% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/nmme.R
\name{read_iri_hindcast}
\alias{read_iri_hindcast}
\title{Read from an NMME hindcast file distributed by IRIDL}
\usage{
read_iri_hindcast(
  fname,
  var,
  target_month,
  lead_months,
  min_target_year = NULL,
  max_target_year = NULL,
  members = NULL,
  progress = FALSE
)
}
\arguments{
\item{fname}{path to netCDF file}

\item{var}{name of forecast variable (e.g., \code{tref})}

\item{target_month}{month targeted by forecast (1-12)}

\item{lead_months}{integer number of lead months, where zero
corresponds to the month when the forecast
was issued}

\item{min_target_year}{only read hindcasts with a target date
greater than or equal to specified year}

\item{max_target_year}{only read hindcasts with a target date
less than or equal to specified year}

\item{members}{one or more ensemble members (1-indexed) to read,
or \code{NULL} to read all ensemble members}

\item{progress}{if \code{TRUE}, show a progress bar during reading}
}
\value{
a 181x360xN array with the values from \code{N} hindcasts
}
\description{
Read from an NMME hindcast file distributed by IRIDL
}
\examples{
\dontrun{
  oct_fcsts <- read_iri_hindcast('cancm4i_tref_hindcast.nc', 'tref', 9, 1)
}
}
