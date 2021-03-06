% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/forecast_correct.R
\name{forecast_correct}
\alias{forecast_correct}
\title{forecast_correct}
\usage{
forecast_correct(distribution, forecast, retro_fit, obs_fit)
}
\arguments{
\item{distribution}{name of distribution used for \code{retro_fit} and \code{obs_fit}}

\item{forecast}{A matrix representing forecast values}

\item{retro_fit}{A 3D array representing GEV distribution parameters
from retrospective forecasts}

\item{obs_fit}{A 3D array representing GEV distribution parameters
from observations}
}
\value{
a matrix with a corrected forecast
}
\description{
Bias-correct a forecast using quantile-matching on computed distributions
of retrospective forecasts and observations.
}
