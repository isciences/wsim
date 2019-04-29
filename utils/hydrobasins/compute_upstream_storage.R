#!/usr/bin/env Rscript

suppressMessages({
  library(dplyr)
  library(sf)
  library(wsim.electricity)
  library(wsim.io)
  library(wsim.lsm)           # for accumulate
  library(wsim.distributions) # to get median flow from distribution
})

'
Compute an upstream storage capacity for each basin

Usage: compute_upstream_storage --flow <file> --dams <file> --basins <file> --sector <sector> --output <file>

Options:
--flow <file>     A fitted distribution of annual total blue water
--dams <file>     A point shapefile of dam locations. Must provide a CAP_MCM field providing
                  reservoir capacity in millions of cubic meters.
--basins <file>   A polygon shapefile providing basin boundaries, used to associate
                  each dam with a basin. Must provide a HYBAS_ID id field and a
                  NEXT_DOWN field indicating the HYBAS_ID of the downstream basin.
--sector <sector> Usage sector for which dams should be filtered.
                  Accepted values: electric_power, agriculture
--output <file>   A netCDF file with a "months_capacity" variable
'->usage

bins <- c(1, 3, 6, 12, 24, 36)

main <- function(raw_args) {
  args <- parse_args(usage, raw_args)

  if (!can_write(args$output))
    die_with_message("Cannot open", args$capacity_file, "for writing.")

  dams <- st_read(args$dams)
  basins <- st_read(args$basins)
  names(dams) <- tolower(names(dams))
  names(basins) <- tolower(names(basins))

  fit <- read_vars(args$flow)
  qua <- wsim.distributions::find_qua(fit$attrs$distribution)

  params <- t(do.call(rbind, fit$data))
  medians <- apply(params, 1, function(p) if (any(is.na(p))) { p[1] } else { qua(0.5, p) })
  flow_df <- as.tbl(data.frame(basin_id=fit$ids, flow_12mo=medians))

  if (args$sector == 'electric_power') {
    # Remove dams that are used for irrigation, water supply, or flood control, unless they're
    # explicitly noted as being used for electricity production
    dams <- filter(dams, !is.na(use_elec) | (is.na(use_irri) & is.na(use_supp) & is.na(use_fcon)))
  } else if (args$sector == 'agriculture') {
    dams <- filter(dams, !is.na(use_irri))
  } else {
    stop('Unknown sector: ', sector)
  }

  basin_capacity <- wsim.electricity::basin_upstream_capacity(
    select(basins, basin_id=hybas_id, downstream_id=next_down),
    select(dams, capacity=cap_mcm))

  basin_months_storage <- left_join(flow_df, basin_capacity, by='basin_id') %>%
    mutate(months_storage=ifelse(is.na(flow_12mo) | flow_12mo <= 0, 0, (capacity+capacity_upstream)*1e6/flow_12mo))

  basin_integration_periods <- basin_capacity %>%
    full_join(flow_df, by='basin_id') %>%
    mutate(months_storage=wsim.electricity::basin_integration_period(
      (capacity + capacity_upstream)*1e6, # basin + upstream capacity as [m^3]
      coalesce(flow_12mo/12, 0),
      bins)) %>%
    select(basin_id, months_storage)

  write_vars_to_cdf(vars=basin_integration_periods[, 'months_storage'],
                    filename=args$output,
                    ids=basin_capacity$basin_id,
      				      prec='integer')
}

main(commandArgs(trailingOnly=TRUE))
