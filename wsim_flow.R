#!/usr/bin/env Rscript
wsim.io::logging_init('wsim_flow')

suppressMessages({
  require(Rcpp)
  require(wsim.lsm)
  require(wsim.io)
})

'
Perform pixel-based flow accumulation

Usage: wsim_flow --input=<file> --flowdir=<file> --varname=<varname> --output=<file> [--wrapx --wrapy]

Options:
--input <file>      file containing values to accumulate (runoff)
--flowdir <file>    file containing flow direction values
--varname <varname> output variable name for accumulated values
--output <file>     file to which accumulated values will be written/appended
--wrapx             wrap flow in the x-dimension
--wrapy             wrap flow in the y-dimension
'->usage

main <- function(raw_args) {
  args <- parse_args(usage, raw_args)

  if (!is.null(args$output) && !can_write(args$output)) {
    die_with_message("Cannot open ", args$output, "for writing.")
  }

  inputs <- wsim.io::read_vars(args$input)
  wsim.io::info("Read input values.")

  flowdir <- wsim.io::read_vars(args$flowdir)
  wsim.io::info("Read flow directions.")

  if (!all(inputs$extent == flowdir$extent)) {
    die_with_message("Extents of inputs and flow directions do not match.")
  }

  if (!all(dim(inputs$data[[1]]) == dim(flowdir$data[[1]]))) {
    die_with_message("Extents of inputs and flow directions do not match.")
  }

  results <- list()
  results[[args$varname]] <- wsim.lsm::accumulate_flow(flowdir$data[[1]],
                                                       inputs$data[[1]],
                                                       args$wrapx,
                                                       args$wrapy)

  info('Flow accumulation complete')

  wsim.io::write_vars_to_cdf(
    vars= results,
    filename= args$output,
    extent= inputs$extent,
    append= TRUE
  )

  info('Wrote results to', args$output)
}

main(commandArgs(trailingOnly=TRUE))
