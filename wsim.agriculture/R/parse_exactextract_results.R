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

#' Parse a data frame representing
#'
#' @param dat a data frame or CSV filename
#' @return a list with data frames of parsed production and loss data
#'
#' @export
parse_exactextract_results <- function(dat) {
  if (is.character(dat)) {
    dat <- utils::read.csv(dat, stringsAsFactors=FALSE)
  }
  
  # Avoid parsing the column names onces per observation, which actually takes about two minutes.
  # Instead, parse them all once and store the results in lookup vectors.
  colname <- names(dat)[-1]
  
  lookup_what <- regmatches(colname, regexpr('[a-z]+', colname))
  names(lookup_what) <- colname
  
  lookup_method <- sapply(regmatches(colname, gregexpr('[a-z]+', colname)), function(m) m[2])
  names(lookup_method) <- colname
  
  lookup_crop <- sapply(regmatches(colname, gregexpr('[a-z]+', colname)), function(m) m[3])
  names(lookup_crop) <- colname 
  
  lookup_subcrop <- sapply(regmatches(colname, gregexpr('[a-z]+(_[0-9]+)?', colname)), function(m) m[3])
  names(lookup_subcrop) <- colname 
  
  lookup_quantile <- sapply(regmatches(colname, gregexpr('(?<=q)[0-9]+', colname, perl=TRUE)), function(m) ifelse(length(m) == 0, NA_integer_, 0.01*as.integer(m)))
  names(lookup_quantile) <- colname
  
  dat <- dplyr::rename(dat, id=1)
  dat <- tidyr::gather(dat, key='colname', value='value', -id)
  dat <- dplyr::transmute(dat, id,
                          what=lookup_what[colname],
                          method=lookup_method[colname],
                          crop=lookup_crop[colname],
                          subcrop=lookup_subcrop[colname],
                          quantile=lookup_quantile[colname],
                          value)
  
  list(
    production=dplyr::select(dplyr::filter(dat, what == 'production'),
                             id, method, crop, subcrop, production=value),
    
    loss=dplyr::select(dplyr::filter(dat, what == 'loss'),
                       id, method, crop, subcrop, quantile, loss=value)
  )
}
