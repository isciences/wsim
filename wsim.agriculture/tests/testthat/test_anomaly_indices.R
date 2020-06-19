# Copyright (c) 2020 ISciences, LLC. 
# All rights reserved.
#
# WSIM is licensed under the Apache License, Version 2.0 (the "License").
# You may not use this file except in compliance with the License. You may
# obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0.
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, e(ither express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

context('Anomaly indices')

test_that('correct indices returned', {
  # yearmon = dec 2019
  # observed data beginning in feb 2018, so 23 months available
  # harvest in may 2020, so months_to_harvest = 5
  # model needs 12 months of data, so the first month of observed data
  # would be june 2019
  # start index would then be 17

  expect_equal(anomaly_start_indices(5, 12, 23), 17)
})


