#!/usr/bin/env Rscript

# Copyright (c) 2018 ISciences, LLC.
# All rights reserved.
#
# WSIM is licensed under the Apache License, Version 2.0 (the "License").
# You may not use this file except in compliance with the License. You may
# obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0.
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

suppressMessages({
  library(wsim.io)
  library(dplyr)
  library(sf)
})

wsim.io::logging_init('append_boundaries')

'
Append fields from boundaries to point data

Usage: append_boundaries --points=<file> --boundaries=<file>... --output=<file>

Options:
--points <file>             Point dataset
--boundaries <file::field>  Polygonal dataset with field to append to point data
--output <file>             Output netCDF with prepared point data
'->usage

#' Produce a correspondonce table between points and at most one polygon
#'
#' @param points sf object with a point geometry
#' @param point_id_field name of identifier in point dataset
#' @param polys sf object with polygonal geometry
#' @param poly_field_in name of identifier in polygon dataset
#' @param poly_field_out name to use for \code{poly_field_in} in output table
#' @param fn function to use to select a polygon when a point falls in more than
#'           one polygon
#' @return a data frame with \code{point_id_field} and \code{poly_field_out} as columns
pip <- function(points, point_id_field, polys, poly_field_in, poly_field_out, fn=first) {
  z <- select(polys, !!rlang::sym(poly_field_in)) %>%
    st_join(select(points, !!point_id_field), join=st_intersects, left=FALSE) %>%
    st_set_geometry(NULL) %>%
    group_by(!!rlang::sym(point_id_field)) %>%
    summarise(poly_id= fn(!!rlang::sym(poly_field_in)))
  names(z) <- c(point_id_field, poly_field_out) # dplyr doesn't seem to be able to use a variable
                                                # for a field name on the left hand side of an
                                                # assignment
  z
}

main <- function(raw_args) {
  args <- wsim.io::parse_args(usage, raw_args)
  points <- wsim.io::read_vars(args$points, as.data.frame=TRUE) %>%
    st_as_sf(coords=c('longitude', 'latitude'), crs=4326, remove=FALSE)

  # TODO check that args$output is writable
  # TODO suppress sf noise throughout file (st_read and st_intersects)

  for (dataset in args$boundaries) {
    split_1 <- strsplit(dataset, '::', fixed=TRUE)[[1]]
    fname <- split_1[1]
    rest <- split_1[2]
    split_2 <- strsplit(rest, '->', fixed=TRUE)[[1]]

    if (length(split_2) == 2) {
      var_in <- split_2[1]
      var_out <- split_2[2]
    } else {
      var_in < rest
      var_out <- rest
    }

    wsim.io::info("Reading", fname)
    polys <- st_read(fname, stringsAsFactors=FALSE)
    pip_result <- pip(points, 'id', polys, var_in, var_out)

    points <- left_join(points, pip_result, by='id')
  }

  points <- st_set_geometry(points, NULL)

  wsim.io::info("Writing points to", args$output)
  wsim.io::write_vars_to_cdf(points[, -1],
                             args$output,
                             ids=points[, 1])
}

tryCatch(main(commandArgs(trailingOnly=TRUE)), error=wsim.io::die_with_message)
