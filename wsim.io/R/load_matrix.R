#' Load raster values to a matrix
#'
#' @param thing a RasterLayer, or a raster file, or a list
#'        containing the above
#' @return
#' @export
load_matrix <- function(thing) {
  if (is.list(thing)) {
    return(lapply(thing, load_matrix))
  }

  if (class(thing) == "RasterLayer") {
    return(raster::as.matrix(thing))
  }

  if (typeof(thing) == "character" && file.exists(thing)) {
    if (endsWith(thing, 'nc')) {
      # Use raster package for now, since it seems to be doing
      # some special handling for NetCDFs?
      return(raster::as.matrix(raster::raster(thing)))
    } else {
      info <- rgdal::GDALinfo(thing, returnStats=FALSE, silent=TRUE)
      dx <- info[["res.x"]]
      dy <- info[["res.y"]]
      xmin <- info[["ll.x"]]
      ymin <- info[["ll.y"]]

      rast <- rgdal::GDAL.open(thing, read.only=TRUE)
      vals <- t(rgdal::getRasterData(rast))
      rgdal::GDAL.close(rast)

      extent <- c(xmin, xmin + dx*dim(vals)[2], ymin, ymin + dy*dim(vals)[1])
      attr(vals, 'extent') <- extent

      return(vals)
    }
  }

  return(thing)
}
