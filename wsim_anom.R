#!/usr/bin/env Rscript
suppressMessages({
  require(wsim.distributions)
  require(wsim.io)
  require(raster)
})

'
Compute standard anomalies and/or return periods

Usage: wsim_anom --fits=<fits> --obs=<file> [--sa=<file>] [--rp=<file>]

--distribution the statistical distribution to be fit
'->usage

args <- parse_args(usage)

if (is.null(args$sa) && is.null(args$rp)) {
  die_with_message("Must write return periods or standard anomalies (--rp and/or --sa)")
}

for (outfile in c(args$sa, args$rp)) {
  if (!is.null(outfile) && !can_write(outfile)) {
    die_with_message("Cannot open ", outfile, " for writing.")
  }
}

fits <- read_fit_from_cdf(args$fits)
obs <- raster(args$obs)

distribution <- metadata(fits)$distribution

if (distribution != 'gev') {
  die_with_message(distribution, " is not a supported statistical distribution.")
}

cdf <- find_cdf(distribution)

sa <- applyDistToStack(
  fits,
  obs,
  function(obs, dist_params) {
    standard_anomaly(cdf, dist_params, obs)
  })

if (!is.null(args$sa)) {
  write_layer_to_cdf(sa, args$sa, "standard_anomaly")
}

if (!is.null(args$rp)) {
  rp <- sa2rp(sa)
  write_layer_to_cdf(rp, args$rp, "return_period")
}
