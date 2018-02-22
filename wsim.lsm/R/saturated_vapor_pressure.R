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

#' Saturated vapor pressure using Buck's equation
#'
#' @param Tm Daily mean temperature (C)
#' @return Vapor pressure (kPa)
#' @export
saturated_vapor_pressure <- function(Tm) {
  0.61121 * exp((18.678 - Tm / 234.5) * Tm / (257.14 + Tm))
}
