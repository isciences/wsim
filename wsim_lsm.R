#!/usr/bin/env Rscript
suppressMessages({
  require(wsim.io)
  require(raster)
})

'
WSIM Land Surface Model

Usage: wsim_lsm --state <file> (--forcing <file>)... --flowdir <file> --wc <file> --elevation <file> [--loop <n>] --results <file> --next_state <file>

Options:

--state <file>       netCDF containing initial model state
--forcing <file>... netCDF file(s) containing model forcing(s)

--flowdir <file>     file containing flow direction grid
--wc <file>          file containing soil water holding capacity
--elevation <file>   file containing elevations

--loop <n>         perform n model iterations using the same forcing data [default: 1]

Output:
--results <file>     filename for model results
--next_state <file>  filename for next state
'->usage

main <- function(raw_args) {
  args <- parse_args(usage, raw_args, types=list(loop="integer"))

  # TODO remove use of load_matrix
  static <- lapply(list(
    flow_directions= args$flowdir,
    Wc= args$wc,
    elevation= args$elevation
  ), wsim.io::load_matrix)

  state <- wsim.lsm::read_state_from_cdf(args$state)
  forcings <- sort(wsim.io::expand_inputs(args$forcing))

  loops <- args$loop

  static$area_m2 <- raster::as.matrix(wsim.lsm::cell_areas_m2(raster::raster(static$elevation,
                                                                             xmn=state$extent[1],
                                                                             xmx=state$extent[2],
                                                                             ymn=state$extent[3],
                                                                             ymx=state$extent[4]
                                                                             )))

  write_all_states <- grepl("%(T|N)", args$next_state)
  write_all_results <- grepl("%(T|N)", args$results)

  results <- NULL
  iter_num <- 0
  for (loop_num in 1:loops) {
    for (i in 1:length(forcings)) {
      iter_num <- iter_num + 1

      forcing <- wsim.lsm::read_forcing_from_cdf(forcings[i])

      cat("Running LSM for ", state$yearmon, ", using ", forcings[i], " ...", sep="")
      iter <- wsim.lsm::run(static, state, forcing)
      cat("done.\n")

      if (write_all_results) {
        fname <- gsub("%T", state$yearmon, args$results)
        fname <- gsub("%N", iter_num, fname)
        cat("  Writing model results to", fname, "\n")
        wsim.lsm::write_lsm_values_to_cdf(iter$obs,
                                          fname,
                                          wsim.lsm::cdf_attrs)
      }

      if (write_all_states) {
        fname <- gsub("%T", iter$next_state$yearmon, args$next_state)
        fname <- gsub("%N", iter_num, fname)
        cat("  Writing next state to", fname, "\n")
        wsim.lsm::write_lsm_values_to_cdf(iter$next_state,
                                          fname,
                                          wsim.lsm::cdf_attrs)
      }

      state <- iter$next_state
      results <- iter$obs

      gc()
    }
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

main(commandArgs(trailingOnly=TRUE))
