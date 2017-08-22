#' Read a gridded binary .mon file
#'
#' Read a gridded binary file of the format described at
#' ftp://ftp.cpc.ncep.noaa.gov/wd51yf/global_monthly/gridded_binary/README.txt
#'
#' The file must be global in extent, with 0.5-degree resolution.
#'
#' @param filename filename to read
#' @param na.value NODATA value, to be replaced with NA
#' @return RasterLayer representing the contents of the .mon file
#' @export
readMonFile <- function(filename, na.value=-999) {
    fh <- file(filename, 'rb')

    # Maximum number of values should be 259200, but some files have more.
    data <- readBin(fh, n = 260000, what = 'numeric', size = 4, endian = 'big')
    close(fh)

    # Check length of data
    if ( length(data) == 259202 ){
        data <- data[-c(1, 259202)]
        warning(basename(filename), ' had 2 extra values.  Removed first and last\n')
    } else if (length(data) > 259202) {
        stop(basename(filename), ' had ', length(data), ' values.  I don\'t know what to do with it.\n')
    }

    # Swap out NODATA value
    data[data == na.value] <- NA

    nx <- 360 / 0.5  # Specify n longitude grid cells
    ny <- 180 / 0.5  # Specify n latitude grid cells

    # Flip and rotate the data
    rast <- raster::raster(nrows = ny, ncols = nx, xmn = 0, xmx = 360)
    rast <- raster::setValues(rast, data)

    rast <- raster::flip(rast, direction = 'y')
    rast <- raster::rotate(rast)

    return(rast)
}
