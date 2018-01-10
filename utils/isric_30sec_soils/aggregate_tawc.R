#!/usr/bin/env Rscript
wsim.io::logging_init('downsample_tawc')

suppressMessages({
  require(wsim.io)
  require(raster)
})

'
Aggregate a raster of TAWC values to a coarser grid

Usage: aggregate_tawc [options]

--res=<value>       Output resolution, degrees
--minlat=<value>    Minimum latitude
--maxlat=<value>    Maximum latitude
--minlon=<value>    Minimum longitude
--maxlon=<value>    Maximum longitude
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
                                         ymx=args$maxlat))


  info("Writing results to", args$output)
  writeRaster(resampled, args$output)
}

tryCatch(main(commandArgs(trailingOnly=TRUE)), error=wsim.io::die_with_message)
