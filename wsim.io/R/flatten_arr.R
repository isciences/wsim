# Copyright (c) 2020 ISciences, LLC.
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

#' Reduce the dimensions of a 3-dimensional array
#'
#' The first two dimensions will be combined, while the third dimension will be preserved.
#'
#' @param arr array to flatten
#' @param varname
#' @export
flatten_arr <- function(arr) {
  old_dim <- dim(arr)
  dim(arr) <- c(prod(dim(arr)[1:2]), dim(arr)[3])
  attr(arr, 'old_dim') <- old_dim
  arr
}
