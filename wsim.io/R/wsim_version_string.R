#' Return a string with the WSIM version and commit hash
#'
#' @export
wsim_version_string <- function() {
  paste0(.WSIM_VERSION,
                " (",
                substr(.WSIM_GIT_COMMIT, 1, 7),
                ")")
}
