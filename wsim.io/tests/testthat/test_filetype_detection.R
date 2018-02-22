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

require(testthat)

context('File type detection')

test_that('Various types of daily precipitation files are recognized', {
  expect_true(is_ncep_daily_precip('/mnt/fig_rw/WSIM_DEV/daily_precip/1989/PRCP_CU_GAUGE_V1.0GLB_0.50deg.lnx.19890402.gz'))
  expect_true(is_ncep_daily_precip('/mnt/fig_rw/WSIM_DEV/daily_precip/2006/PRCP_CU_GAUGE_V1.0GLB_0.50deg.lnx.20060123RT.gz'))
  expect_true(is_ncep_daily_precip('/mnt/fig_rw/WSIM_DEV/daily_precip/2016/PRCP_CU_GAUGE_V1.0GLB_0.50deg.lnx.20160123.RT'))
  expect_true(is_ncep_daily_precip('/mnt/fig_rw/WSIM_DEV/source/NCEP/Daily_precip/2008/PRCP_CU_GAUGE_V1.0GLB_0.50deg.lnx.20080116.RT.gz'))
  expect_false(is_ncep_daily_precip('/mnt/fig_rw/WSIM_DEV/daily_precip/1989/PRCP_CU_GAUGE_V1.0GLB_0.50deg.lnx.19890402.img'))
})
