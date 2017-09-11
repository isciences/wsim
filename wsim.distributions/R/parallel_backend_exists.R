#' Test whether the parallel package has a default cluster
#'
#' @return TRUE if a default cluster is registered
parallel_backend_exists <- function() {
  tryCatch({
    parallel::clusterCall(cl=NULL, identity, 1)
    TRUE
  }, error=function(e) {
    FALSE
  })
}
