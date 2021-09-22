# Copyright (c) 2021 ISciences, LLC.
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

#' Adjust a flow direction matrix for compatibility with other layers
#'
#' Performs the following adjustments:
#' - if \code{fd} is at twice the resolution of other layers, but the latitude
#'   extents are not the same, moves one column of \code{fd} from left to right
#'   if doing so will make the extents equal
#' - pads \code{fd} with \code{NA} values for northern and southern latitudes
#'   included in \code{final_extent} but not \code{fd_extent}.
#'
#' @param fd a flow direction matrix
#' @param fd_extent the spatial extent of \code{fd}, expressed as \code{xmin, xmax, ymin, ymax}
#' @param final_extent desired final extent, expressed as \code{xmin, xmax, ymin, ymax}
#' @param final_dims desired final dimensions
#' @return adjusted version of \code{fd} as described above
#' @export
adjust_flow_dirs <- function(fd, fd_extent, final_extent, final_dims) {
  flow_dim <- dim(fd)
  flow_dlat <- (fd_extent[4] - fd_extent[3]) / flow_dim[1]
  flow_dlon <- (fd_extent[2] - fd_extent[1]) / flow_dim[2]

  if (all(fd_extent[1:2] == final_extent[1:2])) {
    # do nothing
  } else if (flow_dim[2] == 2*final_dims[2]) {
    if (all(fd_extent[1:2] == (final_extent[1:2] - flow_dlon))) {
      # Flow direction raster is double the resolution of other variables and
      # is offset by one half the pixel width of other variables. Rotate a single
      # column from the left of the flow grid to the right.
      fd <- cbind(fd[, -1, drop = FALSE], fd[, 1, drop = FALSE])

      fd_extent[1:2] <- final_extent[1:2]
    } else if (all(fd_extent[1:2] == (final_extent[1:2] + flow_dlon))) {
      # Flow direction raster is double the resolution of other variables and
      # is offset by one half the pixel width of other variables. Rotate a single
      # column from the right of the flow grid to the left.

      fd <- cbind(fd[,  ncol(fd), drop = FALSE],
                  fd[, -ncol(fd), drop = FALSE])
      fd_extent[1:2] <- final_extent[1:2]
    } else {
      stop("Unable to adjust flow direction matrix to desired extent")
    }
  } else {
    stop("Unable to adjust flow direction matrix to desired extent")
  }

  if (fd_extent[3] > final_extent[3]) {
    # pad flow dirs with NA in southern latitudes
    lat_to_pad <- fd_extent[3] - final_extent[3]
    pad_rows <- lat_to_pad / flow_dlat
    fd <- rbind(fd, matrix(NA_integer_, nrow = pad_rows, ncol = flow_dim[2]))
    fd_extent[3] <- final_extent[3]
  } else if (fd_extent[3] < final_extent[3]) {
    stop("Cannot reduce extent of flow direction grid")
  }

  if (fd_extent[4] < final_extent[4]) {
    # pad flow dirs with NA in northern latitudes
    lat_to_pad <- final_extent[4] - fd_extent[4]
    pad_rows <- lat_to_pad / flow_dlat
    fd <- rbind(matrix(NA_integer_, nrow = pad_rows, ncol = flow_dim[2]), fd)
    fd_extent[4] <- final_extent[4]
  } else if (fd_extent[4] > final_extent[4]) {
    stop("Cannot reduce extent of flow direction grid")
  }

  return(fd)
}

