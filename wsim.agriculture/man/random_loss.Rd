% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/random_loss.R
\name{random_loss}
\alias{random_loss}
\title{Generate a value of loss for a single month}
\usage{
random_loss(n_surplus, n_deficit, independent, combine_with, ...)
}
\arguments{
\item{n_surplus}{number of surplus variables}

\item{n_deficit}{number of deficit variables}

\item{independent}{are variables independent (uncorrelated?) if \code{FALSE},
surplus will be assumed to have the same return period as 
heat and deficit will be assumed to have the same return
period as cold.}

\item{combine_with}{specifies how losses from multiple stresses should be
combined. options: [sum, max]}

\item{...}{arguments to pass to \code{loss_function}}
}
\value{
returns a generated loss value from 0 to 1
}
\description{
Generate a value of loss for a single month
}
