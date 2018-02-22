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

wsim.io::logging_init('aggregate_tawc')

suppressMessages({
  require(wsim.io)
  require(raster)
})

'
Aggregate a raster of TAWC values to a coarser grid

Usage: aggregate_tawc --res=<value> [--minlat=<value> --maxlat=<value> --minlon=<value> --maxlon=<value>] --input=<file> --output=<file>

--res=<value>       Output resolution, degrees
--minlat=<value>    Minimum latitude [default: -90]
--maxlat=<value>    Maximum latitude [default: 90]
--minlon=<value>    Minimum longitude [default: -180]
--maxlon=<value>    Maximum longitude [default: 180]
--input=<file>      File containing TAWC at native resolution
--output=<file>     Output file location
'->usage

main <- function(raw_args) {
  args <- parse_args(usage, raw_args, types=list(res="numeric",
                                                 minlat="numeric",
                                                 maxlat="numeric",
                                                 minlon="numeric",
                                                 maxlon="numeric"))

  if (!can_write(args$output)) {
    die_with_message("Can not open", args$output, "for writing.")
  }

  info("Reading TAWC values from", args$input)
  tawc <- raster(args$input)
  info("Aggregating TAWC to resolution of", args$res)
  tawc_agg <- aggregate(tawc, fact=args$res/res(tawc), fun=mean, na.rm=TRUE)

  info("Adjusting TAWC to extent of", args$minlon, args$maxlon, args$minlat, args$maxlat)
  resampled <- resample(tawc_agg, raster(xmn=args$minlon,
                                         xmx=args$maxlon,
                                         ymn=args$minlat,
                                         ymx=args$maxlat,
                                         res=args$res))


  info("Writing results to", args$output)
  writeRaster(resampled, args$output, overwrite=TRUE)
}

tryCatch(main(commandArgs(trailingOnly=TRUE)), error=wsim.io::die_with_message)
#main(commandArgs(trailingOnly=TRUE))
