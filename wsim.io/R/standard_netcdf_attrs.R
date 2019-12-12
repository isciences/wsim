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

#' Generate a list of standard attributes to include in netCDF outputs
#'
#' @param is_new is the file new?
#' @param is_spatial does the file have spatial data?
#' @param existing_history optional character vector with an existing history
#'                         entry to which we should potential apppend
#' @return list of attributes
standard_netcdf_attrs <- function(is_new, is_spatial, existing_history=NULL) {
  history <- paste0(date_string(), ': ', get_command(), '\n')

  if (!is.null(existing_history)) {
    if (endsWith(existing_history, history)) {
      # skip adding history to avoid duplicate entry
      history <- existing_history
    } else if (nchar(existing_history) > 0 && !endsWith(existing_history, '\n')) {
      # previous history entry didn't end with a newline, so we add it here
      history <- paste0(existing_history, '\n', history)
    } else {
      history <- paste0(existing_history, history)
    }
  }

  ret <- list(
    list(key="wsim_version", val=wsim_version_string()),
    list(key="history", val=history)
  )

  if (is_new) {
    ret <- c(ret, list(
      list(key="date_created", val=date_string())
    ))
  }

  if (is_spatial) {
    ret <- c(ret, list(
      # CF conventions require that each measurement can be located
      # on the surface of the Earth. So we only stamp our file with
      # a "Conventions" attribute when writing spatial data.
      list(key="Conventions", val="CF-1.6"),
      list(var="lon", key="axis", val="X"),
      list(var="lon", key="standard_name", val="longitude"),
      list(var="lat", key="axis", val="Y"),
      list(var="lat", key="standard_name", val="latitude")
    ))
  }

  return(ret)
}

date_string <- function() {
  # time_loaded is defined in init.R
  strftime(time_loaded, '%Y-%m-%dT%H:%M:%S%z')
}
