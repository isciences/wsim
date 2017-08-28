#' Run the model using RasterLayers
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
    raster::raster(vals, template=static[[1]])
  }

  to_matrix <- function(thing) {
    if (is.list(thing)) {
      return(lapply(thing, to_matrix))
    }

    if (class(thing) == "RasterLayer") {
      return(raster::as.matrix(thing))
    }

    if (typeof(thing) == "character" && file.exists(thing)) {
      if (endsWith(thing, 'nc')) {
        return(raster::as.matrix(raster::raster(thing)))
      } else {
        rast <- rgdal::GDAL.open(thing, read.only=TRUE)
        vals <- t(rgdal::getRasterData(rast))
        rgdal::GDAL.close(rast)
        return(vals)
      }
    }

    return(thing)
  }

  # Does our "forcings" variable represent a series of forcings
  # (a list of lists), or a single forcing?
  # Coerce it to a list of forcings if needed.
  if (!(is.list(forcings) && all(sapply(forcings, is.list)))) {
    forcings <- list(forcings)
  }

  static.matrix <- to_matrix(static)
  state.matrix <- to_matrix(state)

  iter <- NULL

  i <- 1
  for (forcing in forcings) {
    cat("Processing timestep", i, "of", length(forcings), "\n")

    forcing.matrix <- to_matrix(forcing)
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
    obs=lapply(iter$obs, make_raster),
    next_state=lapply(iter$next_state, make_raster)
  ))
}
