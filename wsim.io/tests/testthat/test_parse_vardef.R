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

context("Parsing variable definitions")

test_that("Filenames and variables are separated", {
  def <- parse_vardef("/home/dan/junkfile.nc::var1,var2")

  expect_equal(def$filename, "/home/dan/junkfile.nc")
  expect_equal(def$vars, list(
    make_var(var_in="var1", var_out="var1"),
    make_var(var_in="var2", var_out="var2")
  ))
})

test_that("Variables can be renamed", {
  def <- parse_vardef("/home/dan/junkfile.nc::1->red,2,3->blue")

  expect_equal(def$vars, list(
    make_var(var_in="1", var_out="red"),
    make_var(var_in="2", var_out="2"),
    make_var(var_in="3", var_out="blue")
  ))

})

test_that("Variables can be transformed", {
  def <- parse_vardef("/home/dan/junkfile.nc::1@negate->neg_red,1->red,2@negate,3->blue")

  expect_equal(def$vars, list(
    make_var(var_in="1", var_out="neg_red", transforms=c("negate")),
    make_var(var_in="1", var_out="red"),
    make_var(var_in="2", var_out="2",       transforms=c("negate")),
    make_var(var_in="3", var_out="blue")
  ))
})

test_that("Multiple transforms are possible", {
  def <- parse_vardef("/home/dan/trash.img::1@negate@fill0->neg_red")

  expect_equal(def$vars, list(
    make_var(var_in="1", var_out="neg_red", transforms=c("negate", "fill0"))
  ))

})
