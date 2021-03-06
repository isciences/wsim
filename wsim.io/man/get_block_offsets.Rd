% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/get_block_offsets.R
\name{get_block_offsets}
\alias{get_block_offsets}
\title{Identify the origin of each block in a GDALRasterBand}
\usage{
get_block_offsets(rband)
}
\arguments{
\item{rband}{a GDALRasterBand object}
}
\value{
a two-column matrix, where each column
        represents the origin offset (row, column)
        of a block
}
\description{
Identify the origin of each block in a GDALRasterBand
}
