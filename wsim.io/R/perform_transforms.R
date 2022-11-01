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

# !diagnostics suppress=body

#' Apply named transformations to data
#'
#' @param data       a numeric vector or matrix
#' @param transforms a character vector of transformation
#'                   descriptions
#' @return a transformed version of \code{data}
perform_transforms <- function(data, transforms) {
  for (transform in transforms) {
    if (transform == "negate") {
      data <- -data
    } else if (transform == "fill0") {
      data[is.na(data)] <- 0
    } else if (transform == "clamp0") {
      data[data < 0] <- 0
    } else if (startsWith(transform, '[') && endsWith(transform, ']')) {
      body <- substr(transform, 2, nchar(transform) - 1)

      # Explicitly create a new matrix whose dimensions match the original
      # This allows us to supply constant-valued functions such as [0] or [1]
      data <- matrix((function(x) eval(parse(text=body)))(data),
                     nrow=nrow(data),
                     ncol=ncol(data))
    } else {
      stop("Unknown transformation ", transforms)
    }
  }

  return(data)
}
