# Copyright (c) 2019 ISciences, LLC.
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

#' Read variables from several files and return a data frame with a "window" column
#'
#' @param vardefs a list of vardefs
#' @param expected_ids expected IDs to check
#' @param as.data.frame return results as a data frame?
#' @return variables at provided integration periods
#' @export
read_integrated_vars <- function(vardefs, expected_ids, as.data.frame=TRUE) {
  if (!as.data.frame) {
    stop("Not implemented yet.")
  }

  dat  <- list()
  common_names <- NULL
  for (vardef in vardefs) {
    df <- read_vars(vardef, expect.ids=expected_ids, as.data.frame=TRUE)

    # Check for global attribute (like we find in distribution fits)
    window <- attr(df, 'integration_window_months')

    # Check for variable attribute on last variable (like we get from wsim_integrate output)
    if (is.null(window)) {
      window <- attr(df[, -1], 'integration_window_months')
    }

    # No attribute. Assume data not time-integrated.
    if (is.null(window)) {
      window <- 1
    }

    if (as.character(window) %in% names(dat)) {
      stop("Duplicate integration period encountered.")
    }

    df$window <- as.integer(window)

    if (is.null(common_names)) {
      common_names <- names(df)
    } else {
      names(df) <- common_names
    }
    dat[[as.character(window)]] <- df
  }

  do.call(function(...) rbind(..., make.row.names=FALSE), dat)
}
