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

#' Read model forcing from a netCDF file
#'
#' @param fname netCDF file containing forcing data
#' @return \code{wsim.lsm.forcing} object containing model forcing
#'
#' @export
read_forcing_from_cdf <- function(fname) {
  contents <- wsim.io::read_vars_from_cdf(fname)

  args <- c(contents["extent"],
            contents$data[c("pWetDays", "T", "Pr")])
  
  # TODO use udunits2 package to pick out synonyms, or
  # perform automatic conversions?
  wsim.io::check_units(contents, 'T',  'degree_Celsius', fname)
  wsim.io::check_units(contents, 'Pr', 'mm', fname)
  
  return(do.call(make_forcing, args))
}

