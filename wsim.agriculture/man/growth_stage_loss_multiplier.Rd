% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/growth_stage_loss_multiplier.R
\name{growth_stage_loss_multiplier}
\alias{growth_stage_loss_multiplier}
\title{Estimate loss multiplier due to growth stage}
\usage{
growth_stage_loss_multiplier(
  day_of_year,
  plant_date,
  harvest_date,
  early_loss_factors,
  late_loss_factors
)
}
\arguments{
\item{day_of_year}{numerical day of year, 1-365}

\item{plant_date}{day of year when planting occurs}

\item{harvest_date}{day of year when harvest occurs}

\item{early_loss_factors}{two-column matrix where first column represents
days since planting and second column represents
a loss multiplier}

\item{late_loss_factors}{two-column matrix where first column represents
days until harvest and second column represents
a loss multiplier}
}
\value{
loss multiplier
}
\description{
Estimate loss multiplier due to growth stage
}
