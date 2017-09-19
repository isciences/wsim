#' Read a gridded binary .mon file
#'
#' Read a gridded binary file of the format described at
#' ftp://ftp.cpc.ncep.noaa.gov/wd51yf/global_monthly/gridded_binary/README.txt
#'
#' The file must be global in extent, with 0.5-degree resolution.
#'
#' @param filename filename to read
#' @param na.value NODATA value, to be replaced with NA
#' @return 360x720 matrix representing the contents of the .mon file
#' @export
read_mon_file <- function(filename, na.value=-999) {
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
    data[data == na.value] <- NA

    data <- matrix(data, nrow=720)
    data <- apply(rbind(data[361:720, ], data[1:360, ]), 1, rev)

    return(data)
}
