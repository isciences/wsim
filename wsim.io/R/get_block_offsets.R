#' Identify the origin of each block in a GDALRasterBand
#'
#' @param rband a GDALRasterBand object
#' @return a two-column matrix, where each column
#'         represents the origin offset (row, column)
#'         of a block
get_block_offsets <- function(rband) {
  block_size <- rgdal::getRasterBlockSize(rband)

  nblocks <- dim(rband) / block_size

  row_offsets <- (seq(nblocks[1]) - 1) * block_size[1]
  col_offsets <- (seq(nblocks[2]) - 1) * block_size[2]

  res <- matrix(NA,
                nrow=prod(nblocks),
                ncol=2)

  i <- 1
  for (row in row_offsets) {
    for (col in col_offsets) {
      res[i, ] <- c(row, col)
      i <- i + 1
    }
  }

  return(res)
}
