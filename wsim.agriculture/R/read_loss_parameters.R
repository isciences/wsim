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

#' Read loss parameters from a file
#' 
#' @param fname filename to read
#' @return list of read parameters
#' @export
read_loss_parameters <- function(fname) {
  params <- utils::read.csv(fname, header=TRUE, colClasses='character', stringsAsFactors=FALSE)
  
  list(
    mean_loss_fit_a= as.numeric(read_key(params, 'mean_loss_fit_a')),
    mean_loss_fit_b= as.numeric(read_key(params, 'mean_loss_fit_b')),
    loss_initial= as.numeric(read_key(params, 'loss_initial')),
    loss_total= as.numeric(read_key(params, 'loss_total')),
    loss_power= as.numeric(read_key(params, 'loss_power')),
    loss_method= as.character(read_key(params, 'loss_method'))
  )
}

read_key <- function(df, param) {
  val <- df[df$param == param, 'value']
  if (length(val) == 0)
    stop('Parameter ', param, ' not found')
  val
}