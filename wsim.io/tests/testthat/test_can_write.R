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
require(wsim.io)

context("File writability")

test_that("Writability of a file is correctly identified", {
  if (Sys.info()[["user"]] == "root") {
    skip("Can't check writiability when running as root")
  }

  expect_true(can_write(tempfile()))
  expect_false(can_write('/root/shouldnt_write_here'))
})

test_that("Checking writability doesn't leave any traces", {
  fname <- tempfile()
  can_write(fname)
  expect_false(file.exists(fname))
})

test_that("Checking writability doesn't affect an existing file", {
  fname <- tempfile()

  fileConn <- file(fname)
  write("cupcake", file=fileConn)
  close(fileConn)

  can_write(fname)

  fileConn <- file(fname)
  contents <- trimws(readChar(fileConn, nchars=100))
  close(fileConn)

  file.remove(fname)

  expect_equal(contents, "cupcake")
})

