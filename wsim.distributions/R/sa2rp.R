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

#' Convert standardized anomaly into a return period
#'
#' @param sa vector or matrix of standardized anomalies
#' @param min.rp minimum value for clamping return period
#' @param max.rp maximum value for clamping return period
#' @return return period
#' @export
sa2rp <- function(sa, min.rp=-1000, max.rp=1000) {
    rp <- sign(sa) / (1 - stats::pnorm(abs(sa)))

    rp <- pmax(rp, min.rp)
    rp <- pmin(rp, max.rp)

    return (rp)
}
