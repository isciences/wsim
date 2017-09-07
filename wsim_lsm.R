#!/usr/bin/env Rscript
suppressMessages({
  require(wsim.io)
  require(raster)
})

'
WSIM Land Surface Model

Usage: wsim_lsm --state <file> [--forcing <file>]... --flowdir <file> --wc <file> --elevation <file> --results <file> --next_state <file>

Options:

--state <file>       netCDF containing initial model state
--forcing <file>... netCDF file(s) containing model forcing(s)

--flowdir <file>     file containing flow direction grid
--wc <file>          file containing soil water holding capacity
--elevation <file>   file containing elevations

Output:
--results <file>     filename for model results
--next_state <file>  filename for next state
'->usage

main <- function() {
  args <- parse_args(usage)

  #args <- list()
  #args$flowdir <- '~/wsim_erdc/inputs/UNH_Data/g_network.asc'
  #args$wc <- '~/wsim_erdc/inputs/HWSD/hwsd_tawc_05deg_noZeroNoVoids.img'
  #args$elevation <- '~/wsim_erdc/inputs/SRTM30/elevation_half_degree.img'
  #args$state <- '/tmp/wsim_init_198101.nc'
  #args$forcing <- '~/wsim_forcing/forcing_198[1-3]*'
  #args$output <- '/tmp/output.nc'
  #args$next_state <- '/tmp/next_state.nc'

  missed_args <- FALSE
  for (arg in names(args)) {
    if (startsWith(arg, '--')) {
      next
    } else {
      if (is.null(args[[arg]])) {
        write(paste0('Missing argument: ', arg), stderr())
        missed_args <- TRUE
      }
    }
  }

  if (missed_args) {
    die_with_message()
  }

  static <- lapply(list(
    flow_directions= args$flowdir,
    Wc= args$wc,
    elevation= args$elevation
  ), wsim.io::load_matrix)

  state <- wsim.lsm::read_state_from_cdf(args$state)
  forcings <- sort(wsim.io::expand_inputs(args$forcing))

  static$area_m2 <- raster::as.matrix(wsim.lsm::cell_areas_m2(raster::raster(static$elevation,
                                                                             xmn=state$extent[1],
                                                                             xmx=state$extent[2],
                                                                             ymn=state$extent[3],
                                                                             ymx=state$extent[4]
                                                                             )))

  write_all_states <- grepl("%T", args$next_state, fixed=TRUE)
  write_all_results <- grepl("%T", args$results, fixed=TRUE)

  results <- NULL
  for (f in forcings) {
    forcing <- wsim.lsm::read_forcing_from_cdf(f)
    cat("Running LSM for ", state$yearmon, ", using ", f, " ...", sep="")
    iter <- wsim.lsm::run(static, state, forcing)
    cat("done.\n")

    if (write_all_results) {
      fname <- gsub("%T", state$yearmon, args$results)
      cat("  Writing model results to", fname, "\n")
      wsim.lsm::write_lsm_values_to_cdf(iter$obs,
                                        fname,
                                        wsim.lsm::cdf_attrs)
    }

    if (write_all_states) {
      fname <- gsub("%T", iter$next_state$yearmon, args$next_state)
      cat("  Writing next state to", fname, "\n")
      wsim.lsm::write_lsm_values_to_cdf(iter$next_state,
                                        fname,
                                        wsim.lsm::cdf_attrs)
    }

    state <- iter$next_state
    results <- iter$obs
  }

  if (!write_all_states) {
    fname <- args$next_state
    cat("  Writing final state to", fname, "\n")
    wsim.lsm::write_lsm_values_to_cdf(state, fname, wsim.lsm::cdf_attrs)
  }
  if (!write_all_results) {
    fname <- args$results
    cat("  Writing results to", fname, "\n")
    wsim.lsm::write_lsm_values_to_cdf(results, fname, wsim.lsm::cdf_attrs)
  }
}

main()
