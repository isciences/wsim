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

context("Reading files with GDAL")

test_that('we can read a specific 2d portion of a variable from a raster file', {
  fname <- tempfile(fileext='.tif')

  data <- matrix(1:15, nrow=3, byrow=TRUE)

  rast_out <- methods::new(suppressMessages(methods::getClassDef('GDALTransientDataset', package='rgdal')),
                           driver=methods::new(methods::getClassDef('GDALDriver', package='rgdal'), 'GTiff'),
                           cols=ncol(data),
                           rows=nrow(data),
                           bands=1,
                           type='float32')

  rast_out <- rgdal::saveDataset(rast_out,
                                 fname,
                                 options=c("COMPRESS=DEFLATE"),
                                 returnNewObj=TRUE)

  rgdal::putRasterData(rast_out, t(data), band=1)
  rgdal::GDAL.close(rast_out)

  entire <- read_vars(fname)
  expect_equal(entire$data[[1]], data, check.attributes=FALSE)

  middle <- read_vars(fname, offset=c(3, 1), count=c(1, -1))
  expect_equal(middle$data[[1]], rbind(3, 8, 13))
  expect_equal(middle$extent, c(2, 3, 0, 3))

  lower_right <- read_vars(fname, offset=c(4, 2), count=c(-1, 2))
  expect_equal(lower_right$data[[1]], rbind(c(9, 10), c(14, 15)), check.attributes=FALSE)
  expect_equal(lower_right$extent, c(3, 5, 0, 2), check.attributes=FALSE)

  file.remove(fname)
})

