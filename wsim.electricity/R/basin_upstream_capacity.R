#' Assign an upstream capacity to each basin
#' 
#' @param basins a \code{sf} with a field for id 
#'               (\code{basin_id}), downstream
#'               basin id (\code{downstream_id})
#' @param dams   a \code{sf} with a field for
#'               capacity (\code{capacity})
#' @return       a data frame with fields \code{hybas_id}
#'               and \code{months_storage}
#' @export
basin_upstream_capacity <- function(basins, dams) {
  stopifnot(inherits(basins, 'sf'))
  stopifnot(inherits(dams, 'sf')) 
  
  stopifnot('basin_id' %in% names(basins))
  stopifnot('downstream_id' %in% names(basins))
  stopifnot('capacity' %in% names(dams))
  
  # Get rid of any unwanted fields that could interfere 
  # with processing
  basins <- dplyr::select(basins, basin_id, downstream_id)
  dams <- dplyr::select(dams, capacity)
  
  # Create our own ID for the dams
  dams$dam_id <- 1:nrow(dams)
  
  # Code below is written in a somewhat awkward style to avoid
  # bringing in magrittr::%>% as a dependency
  dams_basins <- sf::st_join(dams, basins, join=sf::st_intersects, left=TRUE, largest=FALSE)
  dams_basins <- dplyr::summarize(dplyr::group_by(dams_basins, dam_id), basin_id=min(basin_id))
  dams <- sf::st_set_geometry(dams, NULL) # have to drop dam geometry to do non-spatial join
  dams_basins <- dplyr::inner_join(dams_basins, dams, by='dam_id') # bring capacity back in
  dams_basins <- sf::st_set_geometry(dams_basins, NULL)
  
  basins <- dplyr::left_join(basins, dams_basins, by='basin_id')
  basins <- sf::st_set_geometry(basins, NULL)
  basins <- dplyr::group_by(basins, basin_id, downstream_id)
  basins <- dplyr::summarise(basins, capacity=dplyr::coalesce(sum(capacity), 0))
  basins <- dplyr::ungroup(basins)
  basins <- dplyr::mutate(basins, capacity_upstream=wsim.lsm::accumulate(basin_id, downstream_id, capacity)-capacity)
  
  dplyr::select(basins, basin_id, capacity, capacity_upstream)
}
