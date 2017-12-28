#!/usr/bin/env Rscript

wsim.io::logging_init('extract_isric_tawc')

'
Produce a GeoTIFF of TAWC (mm) from the ISRIC 30-second WISE-derived soil properties dataset

TAWC is computed by summing the weighted-average water capacity of each layer having a bottom depth
less than the specified maximum. (If the specified maximum is in the middle of a layer, it will be
omitted from the sum.) The weighted-average capacity of each layer is computed according to the
proportions of each soil type specified in the input data file.

A supplementary file must be provided to specify placeholder TAWC values for the following missing
data TAWC values:
* -1: Water bodies
* -2: Land ice and glaciers
* -3: Rock outcrops
* -4: Dunes, shifting sands
* -5: Salt flats
* -7: Rocky sublayers
* -9: Urban areas, other miscellaneous units

Usage: extract_isric_tawc [--max_depth=<depth> --data=<data> --missing=<missing> --codes=<codes> ] --output=<output>

--data=<data>       comma-separated file with soil parameters for all map units [default: HW30s_FULL.txt]
--missing=<missing> comma-separated file defining TAWC values (cm/m) for missing data codes [default: tawc_missing.csv]
--codes=<codes>     tab-separated file linking map unit codes to integer values in raster file [default: wise_30sec_v1.tsv]
--raster=<raster>   raster file of integer values corresponding to map units [default: wise_30sec_v1.tif]
--max_depth=<depth> maximum depth of water holding capacity in meters [default: 1]
--output=<output>   output csv linking integer codes to computed TAWC [default: wise_30sec_v1_tawc.tif]
'->usage

suppressMessages({
  require(dplyr)
  require(readr)
  require(wsim.io)
})

#' Add variables to WISE data containing depths in meters and TAWC in mm
standardize_units <- function(data) {
  mutate(data,
         BotDep_m= BotDep/100, # cm to m
         TopDep_m= TopDep/100, # cm to m
         TAWC_mm=  TAWC*10)    # cm to mm
}

#' Compute a TAWC across multiple layers by a weighted average of multiple soil types
#'
#' @param data data frame containing the following variables
#' \itemize{
#'  \item NEWSUID   Unique identifier for soil map unit
#'  \item Layer     Name for this layer in the profile (e.g., "D1", "D2", etc.)
#'  \item TopDep_m  Top depth of layer (m)
#'  \item BotDep_m  Bottom depth of layer (m)
#'  \item PROP      Relative proportion of soil type in the map unit
#'  \item TAWC      Available water capacity for this soil type/layer (mm/m)
#' }
#' @param max_depth_m Maximum soil depth in meters to consider
weighted_mean_tawc <- function(data, max_depth_m) {
  # Ignore layers deeper than specified max depth
  filter(data, BotDep_m <= max_depth_m) %>%
  # Compute the holding capacity of each layer
  mutate(thickness_m= BotDep_m-TopDep_m) %>%
  mutate(layer_capacity_mm= TAWC_mm*thickness_m) %>%
  # Each NEWSUID may have multiple soil types at various proportions.
  # So we calculate a weighted mean of water holdinc capacity, according
  # to the specified propertion of each type
  group_by(NEWSUID, Layer) %>%
  summarise(avg_layer_capacity_mm = weighted.mean(layer_capacity_mm, PROP)) %>%
  group_by(NEWSUID) %>%
  # TAWC is then computed as the sum of each layer's weighted average capacity
  summarise(TAWC= sum(avg_layer_capacity_mm))
}

#' Create a vector for fast lookup of TAWC values
#'
#' @param codes A dataframe
#' @return A vector where v[i+1] provides the value of TAWC for pixel value \code{i}
make_code_array <- function(codes) {
  code_array <- rep.int(NA_real_, 1 + max(codes$pixel_value))

  for (i in 1:nrow(codes)) {
    offset_pixel_value <- codes$pixel_value[i] + 1
    tawc <- codes$TAWC[i]

    code_array[offset_pixel_value] <- tawc
  }

  return(code_array)
}

run_tests <- function() {
  require(testthat)

  test_that('TAWC is computed as a sum of all layers less than target depth', {
    test_data <- rbind.data.frame(
      list(NEWSUID=1, Layer="D1", PROP=100, TopDep_m=0,    BotDep_m=0.5,  TAWC_mm=15),
      list(NEWSUID=1, Layer="D2", PROP=100, TopDep_m=0.5,  BotDep_m=0.75, TAWC_mm=17),
      list(NEWSUID=1, Layer="D3", PROP=100, TopDep_m=0.75, BotDep_m=1.00, TAWC_mm=19),
      list(NEWSUID=1, Layer="D4", PROP=100, TopDep_m=1.00, BotDep_m=2.00, TAWC_mm=21)
    )

    expect_equal(weighted_mean_tawc(test_data, max_depth_m=1.00)$TAWC, 0.5*15 + 0.25*17 + 0.25*19)
    expect_equal(weighted_mean_tawc(test_data, max_depth_m=0.60)$TAWC, 0.5*15)
  })

  test_that('When multiple soil types are present, TAWC is computed as a weighted average', {
    test_data <- rbind.data.frame(
      list(NEWSUID=1, Layer="D1", SCID="A", PROP=70, TopDep_m=0.0, BotDep_m=0.4, TAWC_mm=15),
      list(NEWSUID=1, Layer="D2", SCID="A", PROP=70, TopDep_m=0.4, BotDep_m=0.6, TAWC_mm=17),
      list(NEWSUID=1, Layer="D1", SCID="B", PROP=30, TopDep_m=0.0, BotDep_m=0.4, TAWC_mm=19),
      list(NEWSUID=1, Layer="D2", SCID="B", PROP=30, TopDep_m=0.4, BotDep_m=0.6, TAWC_mm=21)
    )

    expect_equal(weighted_mean_tawc(test_data, max_depth_m=0.50)$TAWC,
                 0.4*(15*0.7 + 19*0.3))

    expect_equal(weighted_mean_tawc(test_data, max_depth_m=1.00)$TAWC,
                 0.4*(15*0.7 + 19*0.3) +
                 0.2*(17*0.7 + 21*0.3))

  })
}

main <- function(raw_args) {
  args <- parse_args(usage, raw_args)

  if (!can_write(args$output)) {
    die_with_message("Can not open", args$output, "for writing.")
  }

  info("Reading WISE data from", args$data)
  data <- suppressMessages(read_csv(args$data))
  info("Reading pixel value - map unit correlation from", args$codes)
  codes <- suppressMessages(read_tsv(args$codes))

  info("Reading TAWC values for missing data from", args$missing)
  missing_codes <- as.vector(t(suppressMessages(read_csv(args$missing))))

  info("Replacing missing TAWC data with default values")
  data <- mutate(data, TAWC= wsim.distributions::substitute(TAWC, missing_codes))
  # Check that all missing data has been handle
  if (any(data$TAWC < 0)) {
    die_with_message("Unhandled negative TAWC value.")
  }

  data <- standardize_units(data)
  info("Computing TAWC for each map unit")
  tawc <- weighted_mean_tawc(data, args$max_depth)

  if (nrow(tawc) != length(unique(data$NEWSUID))) {
    die_with_message("Could not compute TAWC for all map units.")
  }

  tawc_for_pixel <- tawc %>%
    inner_join(codes, by=c("NEWSUID"="description")) %>%
    rename(pixel_value= pixel_vaue) %>%
    dplyr::select(pixel_value, TAWC)

  code_array <- make_code_array(tawc_for_pixel)

  info("Creating TAWC raster file")
  raster_blockwise_apply(args$raster,
                         args$output,
                         function(vals) {
                           code_array[1 + vals]
                         },
                         nodata=-3.4028234663852886e+38,
                         datatype='Float32')

  info("Wrote TAWC values to", args$output)
}

tryCatch(main(commandArgs(trailingOnly=TRUE)), error=wsim.io::die_with_message)
