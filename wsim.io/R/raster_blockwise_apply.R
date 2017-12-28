#' Apply a function to each cell in a GDALRasterDataset, using blockwise I/O
#'
#' @param rast     A GDALRasterDataset from which values should be read
#' @param rast_out A GDALRasterDataset to which values should be written
#' @param fun      A function to apply to each cell in \code{rast}
#' @param band     The band of \code{rast} to read
#'
#' @export
block_apply <- function(rast, rast_out, fun, band=1) {
  band_obj <- rgdal::getRasterBand(rast, band=band)
  block_size <- rgdal::getRasterBlockSize(band_obj)

  block_offsets <- get_block_offsets(band_obj)

  data_min <- Inf
  data_max <- -Inf
  data_sum <- 0
  data_n   <- 0

  for (r in 1:nrow(block_offsets)) {
    offset <- block_offsets[r, ]
    data <- rgdal::getRasterData(rast,
                                 band=band,
                                 offset=offset,
                                 region.dim=block_size,
                                 as.is=TRUE)

    data_out <- fun(data)
    data_min <- min(data_min, data_out, na.rm=TRUE)
    data_max <- max(data_max, data_out, na.rm=TRUE)
    data_sum <- data_sum + sum(data_out, na.rm=TRUE)
    data_n   <- data_n + sum(!is.na(data_out))

    rgdal::putRasterData(rast_out,
                         data_out,
                         band=1,
                         offset=offset)
  }

  .Call('RGDAL_SetStatistics',
        rgdal::getRasterBand(rast_out, band=1),
        c(data_min, data_max, data_sum / data_n, NA),
        PACKAGE='rgdal')
}

#' Create a new GeoTIFF with the same dimensions/projection the input
#'
#' @param rast         a GDALRasterDataset
#' @param filename_out filename of output GeoTIFF
#' @param datatype     datatype of values in output GeoTIFF
#' @return a GDALRasterDataset pointing to the output GeoTIFF
#' @export
create_tiff_like <- function(rast, filename_out, datatype) {
  # By default, GDAL will make sure that we have enough space
  # to write the data without compression. Since we're using
  # compression, we want to disable this check.
  rgdal::setCPLConfigOption('CHECK_DISK_FREE_SPACE', 'FALSE')

  # To create a new disk-based dataset, we first instantiate
  # a "GDALTransientDataset", and then save it to disk. This
  # leaves us with a regular a "GDALDataset" object that we
  # can write data to.
  rast_out <- methods::new(suppressMessages(methods::getClassDef('GDALTransientDataset', package='rgdal')),
                           driver=methods::new(methods::getClassDef('GDALDriver', package='rgdal'), 'GTiff'),
                           cols=ncol(rast),
                           rows=nrow(rast),
                           bands=1,
                           type=datatype)
  rast_out <- rgdal::saveDataset(rast_out,
                                 filename_out,
                                 options=c("COMPRESS=DEFLATE"),
                                 returnNewObj=TRUE)

  # Set output CRS to match input
  .Call('RGDAL_SetProject', rast_out, rgdal::getProjectionRef(rast), PACKAGE='rgdal')

  # Set output transform to match input
  transform <- .Call('RGDAL_GetGeoTransform', rast, PACKAGE='rgdal')
  .Call('RGDAL_SetGeoTransform', rast_out, transform, PACKAGE='rgdal')

  return(rast_out)
}

#' Apply a function to each cell of a raster, using blockwise I/O
#'
#' @param filename     Filename of raster to read
#' @param filename_out Filename of output GeoTIFF
#' @param fun          Function to apply to each cell of input
#' @param datatype     Data type of output raster (allowable type
#'                     names are defined by the \code{rgdal} package.)
#' @export
raster_blockwise_apply <- function(filename,
                                   filename_out,
                                   fun,
                                   band=1,
                                   datatype='Float32') {
  rast <- rgdal::GDAL.open(filename, read.only=TRUE)
  rast_out <- create_tiff_like(rast, filename_out, datatype)

  block_apply(rast, rast_out, fun, band=band)

  rgdal::GDAL.close(rast)
  rgdal::GDAL.close(rast_out)
}
