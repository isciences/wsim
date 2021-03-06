% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/mirca_area_fraction_grid.R
\name{create_default_area_frac_df}
\alias{create_default_area_frac_df}
\title{Create a data frame that identifies provides a fallback area_frac if one
is not declared in the crop calendar.}
\usage{
create_default_area_frac_df(calendar_df)
}
\arguments{
\item{calendar_df}{a MIRCA crop calendar data frame}
}
\value{
a data frame with \code{unit_code}, \code{crop}, \code{subcrop}, \code{default_area_frac}
}
\description{
If all subcrops have an undefined area fraction, the area fractions can
remain undefined. However, if only some subcrops have an undefined area
fraction, we coalesce the undefined values to zero. This is necessary to
create an area fraction grid that can be aggregated to a lower resolution.
If the NA values described above are not coalesced, then an aggregated
area fraction grid will have area fraction sums above 1.0.
}
