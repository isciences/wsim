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

context('Basin upstream capacity')

make_box <- function(xmin, ymin, xmax, ymax) {
  sf::st_polygon(list(matrix(c(
    xmin, ymin, 
    xmax, ymin,
    xmax, ymax,
    xmin, ymax,
    xmin, ymin), ncol=2, byrow=TRUE)))
}

## 1--- 2 --- 3
##  \-- 4 --- 5
test_that('correct capacity determined', {
  basins <- sf::st_sf(basin_id=c(1,2,3,4,5),
                      downstream_id=c(0,1,2,1,4),
                      geom=sf::st_sfc(make_box(1, 1, 2, 2),
                                      make_box(2, 1, 3, 2),
                                      make_box(3, 1, 4, 2),
                                      make_box(1, 0, 2, 1),
                                      make_box(2, 0, 3, 1)))
  
  dams <- sf::st_sf(capacity=c(7, 11, 13, 17, 21),
                    geom=sf::st_sfc(sf::st_point(c(1.5, 1.5)),  # in basin 1
                                    sf::st_point(c(3.5, 1.5)),  # in basin 3
                                    sf::st_point(c(3.2, 1.1)),  # in basin 3
                                    sf::st_point(c(1.5, 0.7)),  # in basin 4
                                    sf::st_point(c(1.5, 1.0)))) # in both basins 1 and 4
                                                                # should only count it once and
                                                                # assign to lowest-id basin
  
  capacities <- basin_upstream_capacity(basins, dams) 
  expect_equal(basins$basin_id, capacities$basin_id)
  
  expect_equal(sum(capacities$capacity), sum(dams$capacity))
  
  expect_equal(capacities$capacity, c(7+21, 0, 11+13, 17, 0))
  expect_equal(capacities$capacity_upstream, c(24+17, 24, 0, 0, 0))
})
