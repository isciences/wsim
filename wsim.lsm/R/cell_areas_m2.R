#' Compute the area occupied by each cell of a matrix
#'
#' Calculation is performed using spherical geometry
#'
#' @param extent a vector representing the spatial extent of the matrix
#'               (\code{xmin, xmax, ymin, ymax})
#' @param dim the dimensions of the matrix (\code{nlat, nlon})
#' @return a matrix having dimension \code{dim} and values representing
#'         the area occupied by each cell
#'
#' @export
cell_areas_m2 <- function(extent, dim) {
  radius_m <- 6378000
  dlon <- (extent[2] - extent[1]) / dim[2]
  dlat <- (extent[4] - extent[3]) / dim[1]

  lats <- seq(from=extent[4]-0.5*dlat, to=extent[3]+0.5*dlat, by=-dlat)

  areas <- sapply(lats, function(lat) {
    lat1 <- lat - dlat/2
    lat2 <- lat + dlat/2

    return(pi / 180 * radius_m^2 * abs(sin(lat1 * pi / 180) - sin(lat2 * pi / 180)) * dlon)
  })

  return(array(areas, dim=dim))
}
