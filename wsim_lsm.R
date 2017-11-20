#!/usr/bin/env Rscript
wsim.io::logging_init('wsim_lsm')

suppressMessages({
  require(Rcpp)
  require(wsim.io)
})

'
WSIM Land Surface Model

Usage: wsim_lsm --state <file> (--forcing <file>)... --flowdir <file> --wc <file> --elevation <file> [--loop <n>] --results <file> --next_state <file>

Options:

--state <file>       netCDF containing initial model state
--forcing <file>...  netCDF file(s) containing model forcing(s)

--flowdir <file>     file containing flow direction grid
--wc <file>          file containing soil water holding capacity
--elevation <file>   file containing elevations

--loop <n>         perform n model iterations using the same forcing data [default: 1]

Output:
--results <file>     filename for model results
--next_state <file>  filename for next state
'->usage

read_static_data <- function(args) {
  static <- list()
  elevation <- wsim.io::read_vars(args$elevation, expect.nvars=1)

  extent <- elevation$extent
  dims <- dim(elevation$data[[1]])

  static$elevation <- elevation$data[[1]]
  static$flow_directions <- wsim.io::read_vars(args$flowdir,
                                               expect.nvars=1,
                                               expect.extent=extent,
                                               expect.dims=dims)
  static$Wc <- wsim.io::read_vars(args$wc,
                                  expect.nvars=1,
                                  expect.extent=extent,
                                  expect.dims=dims)

  return(static)
}

main <- function(raw_args) {
  args <- parse_args(usage, raw_args, types=list(loop="integer"))

  static <- read_static_data(args)
  state <- wsim.lsm::read_state_from_cdf(args$state)
  forcings <- sort(wsim.io::expand_inputs(args$forcing))

  loops <- args$loop

  write_all_states <- grepl("%(T|N)", args$next_state)
  write_all_results <- grepl("%(T|N)", args$results)

  results <- NULL
  iter_num <- 0
  for (loop_num in 1:loops) {
    for (i in seq_along(forcings)) {
      iter_num <- iter_num + 1

      forcing <- wsim.lsm::read_forcing_from_cdf(forcings[i])

      wsim.io::info("Running LSM for", state$yearmon, "using", forcings[i], "...")
      iter <- wsim.lsm::run(static, state, forcing)
      wsim.io::info("done.")

      if (write_all_results) {
        fname <- gsub("%T", state$yearmon, args$results)
        fname <- gsub("%N", iter_num, fname)
        wsim.io::info("Writing model results to", fname)
        wsim.lsm::write_lsm_values_to_cdf(iter$obs, fname)
      }

      if (write_all_states) {
        fname <- gsub("%T", iter$next_state$yearmon, args$next_state)
        fname <- gsub("%N", iter_num, fname)
        wsim.io::info("  Writing next state to", fname)
        wsim.lsm::write_lsm_values_to_cdf(iter$next_state, fname)
      }

      state <- iter$next_state
      results <- iter$obs

      gc()
    }
  }

  if (!write_all_states) {
    fname <- args$next_state
    wsim.io::info("Writing final state to", fname)
    wsim.lsm::write_lsm_values_to_cdf(state, fname)
  }
  if (!write_all_results) {
    fname <- args$results
    wsim.io::info("Writing results to", fname)
    wsim.lsm::write_lsm_values_to_cdf(results, fname)
  }
}

tryCatch(main(commandArgs(trailingOnly=TRUE)), error=wsim.io::die_with_message)
