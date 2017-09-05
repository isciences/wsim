#' Compute the area occupied by each cell of a RasterLayer
#'
#' @param An object that is coercible to a RasterLayer,
#'        with a defined extent assumed to be in lon-lat
#'        coordinates
#'
#' @return A RasterLayer with the same extent and resolution
#'         as the input
#'
cell_areas_m2 <- function(rast) {
  areas <- raster::raster(rast)
  dlon <- raster::res(rast)[1]
  dlat <- raster::res(rast)[2]
  radius_m <- 6378000

  cmp <- sapply(raster::yFromRow(rast, 1:nrow(rast)), function(lat) {
    lat1 <- lat - dlat/2
    lat2 <- lat + dlat/2

    return(pi / 180 * radius_m^2 * abs(sin(lat1 * pi / 180) - sin(lat2 * pi / 180)) * dlon)
  })

  raster::values(areas) <- rep(cmp, each=ncol(areas))

  return(areas)
}
