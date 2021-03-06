% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/RcppExports.R
\name{pe3_forecast_correct}
\alias{pe3_forecast_correct}
\title{Bias-correct a forecast using Pearson Type-III distribution}
\usage{
pe3_forecast_correct(
  data,
  obs_location,
  obs_scale,
  obs_shape,
  retro_location,
  retro_scale,
  retro_shape,
  extreme_cutoff,
  when_dist_undefined
)
}
\arguments{
\item{data}{matrix representing forecast values}

\item{obs_location}{location parameter from observed data}

\item{obs_scale}{scale parameter from observed data}

\item{obs_shape}{shape parameter from observed data}

\item{retro_location}{location parameter from retrospective data}

\item{retro_scale}{scale parameter from retrospective data}

\item{retro_shape}{shape parameter from retrospective data}

\item{extreme_cutoff}{clamping value for computed forecast quantiles
(\code{1/extreme_cutoff < quantile < 1 - 1/extreme_cutoff})}

\item{when_dist_undefined}{assumed quantile of forecast when
retrospective distribution is undefined}
}
\description{
Bias-correct a forecast using quantile-matching on computed distributions
of retrospective forecasts and observations.
}
