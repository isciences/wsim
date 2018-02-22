# Copyright (c) 2018 ISciences, LLC.
# All rights reserved.
#
# WSIM is licensed under the Apache License, Version 2.0 (the "License").
# You may not use this file except in compliance with the License. You may
# obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0.
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

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
