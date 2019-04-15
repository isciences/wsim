#' Return a data frame with each combination of the supplied inputs
#'
#' @param ... one or more named arguments
#' @return a data frame
combos <- function(...) {
  args <- rev(list(...))

  lens <- sapply(args, length)

  repeated <- lapply(1:length(args), function(i) {
    each  <- lens[(i+1):length(args)]
    times <- lens[0:(i-1)]

    rep(
      rep(
        args[[i]],
        each=prod(each)),
      times=prod(times))
  })
  names(repeated) <- names(args)

  repeated$stringsAsFactors <- FALSE
  do.call(data.frame, rev(repeated))
}
