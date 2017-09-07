#' Run the model using RasterLayers
#'
#' Supplied references may be RasterLayers, or filenames
#'
#' @param static a list containing static inputs to the model
#' @param state a list containing an input state for the model
#' @param forcing a list containing forcing data for the model
#' @param iter_fun an optional callback that will be called after
#'                 each iteration with the 1-indexed iteration number
#'                 and the iteration results as arguments.
#'
#' @return a list containing model outputs and a state for the next time step.
#' @export
run_with_rasters <- function(static, state, forcings, iter_fun=NULL) {
  make_raster <- function(vals) {
    if (is.matrix(vals)) {
      return(raster::raster(vals, template=static[[1]]))
    }
    return(vals)
  }

  # Does our "forcings" variable represent a series of forcings
  # (a list of lists), or a single forcing?
  # Coerce it to a list of forcings if needed.
  if (!(is.list(forcings) && all(sapply(forcings, is.list)))) {
    forcings <- list(forcings)
  }

  # Compute cell areas for use within the model
  static$area_m2 <- cell_areas_m2(raster::raster(static$elevation))

  static.matrix <- wsim.io::load_matrix(static)
  state.matrix <- wsim.io::load_matrix(state)

  iter <- NULL

  i <- 1
  for (forcing in forcings) {
    cat("Processing timestep", i, "of", length(forcings), "\n")

    forcing.matrix <- wsim.io::load_matrix(forcing)

    iter <- run(static.matrix, state.matrix, forcing.matrix)
    state.matrix <- iter$next_state

    if (!is.null(iter_fun)) {
      iter_fun(i, list(
        forcing=forcing,
        obs=lapply(iter$obs, make_raster),
        next_state=lapply(iter$next_state, make_raster)
      ))
    }

    i <- i + 1
  }

  return(list(
    forcing=forcing,
    obs=lapply(iter$obs, make_raster),
    next_state=lapply(iter$next_state, make_raster)
  ))
}
