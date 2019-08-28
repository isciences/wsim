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

#' Apply a function to each pixel of a stack of matrices
#'
#' @param arr a three-dimensional array
#' @param fun a function to apply at each row and column of the input
#'            array. The function will be called with a vector of the
#'            z-values as a single argument.
#' @param ... additional arguments to be passed to \code{fun}
#' @return an array containing the values returned by \code{fun} at
#'         each pixel
#' @export
array_apply <- function(arr, fun, ...) {
  if (parallel_backend_exists()) {
    apply_fn <- parallel::parApply
  } else {
    apply_fn <- apply
  }

  return(aperm(apply_fn(X=arr, MARGIN=c(2,1), FUN=fun, ...)))
}
