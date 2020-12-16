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

context('MIRCA area fraction grid')

test_that('Aggregated values sum to one', {
  set.seed(123) 
  
  nrow <- 8
  ncol <- 8
  
  cal <- dplyr::tribble(
    ~unit_code, ~crop, ~subcrop, ~area_frac,
    # unit 1: both subcrops specified
    1, 1, 1, 0.6,
    1, 1, 2, 0.4,
    
    # unit 2: no subcrops specified
    
    # unit 3: only one subcrop specified
    3, 1, 1, 1.0,
    
    1, 2, 1, 1.0
  ) 
  
  units <- matrix(sample(cal$unit_code, nrow*ncol, replace=TRUE),
                  nrow = nrow,
                  ncol = ncol)
  
  units[sample(nrow*ncol, nrow)] <- NA
  
  afrac_1 <- mirca_area_fraction_grid(units, cal, 1, 1)
  afrac_2 <- mirca_area_fraction_grid(units, cal, 1, 2)
  
  afrac_tot <- psum(afrac_1, afrac_2)
  expect_true(all(is.na(afrac_tot) | abs(afrac_tot - 1) < 1e-6))
  
  afrac_1a <- aggregate_mean(afrac_1, 4)
  afrac_2a <- aggregate_mean(afrac_2, 4)
  
  afrac_tota <- psum(afrac_1a, afrac_2a)
  expect_true(all(is.na(afrac_tota) | abs(afrac_tota - 1) < 1e-6))
})