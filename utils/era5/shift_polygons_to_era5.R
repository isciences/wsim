#!/usr/bin/env Rscript

# Copyright (c) 2022 ISciences, LLC.
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

wsim.io::logging_init('shift_polygons_to_era5')

suppressPackageStartupMessages({
  library(dplyr)
  library(sf)
  library(lwgeom)
})

'
Shift polygons to modified ERA5 grid used by WSIM

Usage: shift_polygons_to_era5.R --input=<file> --output=<file>

Options:
--input <file> Input file
--output <file> Output file
'->usage

main <- function(raw_args) {
  args <- wsim.io::parse_args(usage, raw_args)

  suppressMessages({
    sf_use_s2(FALSE)
  })

  sf::sf_use_s2(FALSE)

  # Split polygons are -179.875 meridian. This leaves us with
  # some GeometryCollections, and sf offers no simple way to
  # turn them back into MultiPolygons. So we explode them to
  # polygons and use an inner join to reconstitue them as
  # MultiPolygons.
  polys <- st_read(args$input, quiet = TRUE) %>%
    st_wrap_x(wrap = -179.875, move = 360) %>%
    mutate(.f = seq_len(dplyr::n()))

  attrs <- st_drop_geometry(polys)

  polys <- polys %>%
    st_collection_extract('POLYGON') %>%
    group_by(.f) %>%
    summarize(do_union = TRUE) %>%
    inner_join(attrs, by = '.f') %>%
    select(-.f)

  st_write(polys, args$output)
}

tryCatch(main(commandArgs(trailingOnly=TRUE)), error=wsim.io::die_with_message)


