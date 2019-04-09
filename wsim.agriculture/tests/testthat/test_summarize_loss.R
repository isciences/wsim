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

context('Summarizing loss values')

set.seed(123)
prod <- data.frame(
  id=1:3,
  method='irrigated',
  crop=rep(c('maize', 'maize', 'cotton'), each=3),
  subcrop=rep(c('maize_1', 'maize_2', 'cotton'), each=3),
  production=c(100, 10, 3, 
               0,   20, 0, 
               3,    8, 0),
  stringsAsFactors=FALSE
)
prod <- rbind(prod,
              dplyr::mutate(prod, method='rainfed', production=0.5*production))

loss <- data.frame(
  id=1:3,
  method='rainfed',
  crop=rep(c('maize', 'maize', 'cotton'), each=3),
  subcrop=rep(c('maize_1', 'maize_2', 'cotton'), each=3),
  quantile=0.5,
  loss_frac=c(0.2, 0.4, 0.3,
              0.2, 1.0, 0.0,
              0.0, 0.6, 0.4),
  stringsAsFactors=FALSE
)
loss <- rbind(loss,
              dplyr::mutate(loss, quantile=0.25, loss_frac=loss_frac*runif(dplyr::n())),
              dplyr::mutate(loss, quantile=0.75, loss_frac=pmax(loss_frac*(1 + runif(dplyr::n())), 1.0)))
loss <- rbind(loss, dplyr::mutate(loss, method='rainfed', loss_frac=0.0))
loss <- dplyr::select(
  dplyr::mutate(
    dplyr::inner_join(loss, prod, by=c('id', 'subcrop', 'crop', 'method')),
    loss=loss_frac*production),
  id, method, crop, subcrop, quantile, loss
)

summarized <- summarize_loss(prod, loss)

test_that('whenever there is production, the aggregated loss is finite', {
  for (method in names(summarized)) {
    expect_true(all(is.finite(summarized[[method]]$production)))
    expect_true(all(summarized[[method]]$production == 0 | is.finite(summarized[[method]]$loss)))
  }  
})

test_that('correct number of rows output', {
  ids <- length(unique(loss$id))
  crops <- length(unique(loss$crop))
  quantiles <- length(unique(loss$quantile))
  
  expect_equal(nrow(summarized$overall), ids*quantiles)
  expect_equal(nrow(summarized$by_type), ids*quantiles*2)
  expect_equal(nrow(summarized$by_crop), ids*crops*quantiles)
})

test_that('per-crop loss can be formatted for writing to disk (with quantiles)', {
  formatted <- format_loss_by_crop(summarized$by_crop)
  
  expect_named(formatted,
               c('id', 'crop', 'loss_q25', 'loss_q50', 'loss_q75'))
  
  # spot-check a value
  expect_equal(dplyr::filter(formatted, id==2 & crop=='cotton')$loss_q75,
               dplyr::filter(summarized$by_crop, id==2 & quantile==0.75 & crop=='cotton')$loss)
  
})

test_that('per-crop loss can be formatted for writing to disk (without quantiles)', {
  to_format <- dplyr::mutate(dplyr::filter(summarized$by_crop, quantile==0.50), quantile=NA)
  formatted <- format_loss_by_crop(to_format)
  
  expect_named(formatted,
               c('id', 'crop', 'loss'))
  
  # spot-check a value
  expect_equal(dplyr::filter(formatted, id==2 & crop=='cotton')$loss,
               dplyr::filter(summarized$by_crop, id==2 & quantile==0.5 & crop=='cotton')$loss)
  
})

test_that('overall loss can be formatted for writing to disk (with quantiles)', {
  formatted <- format_overall_loss(summarized$overall)
  
  expect_named(formatted,
               c('id', 'loss_overall_q25', 'loss_overall_q50', 'loss_overall_q75'))
  
  # spot-check a value
  expect_equal(dplyr::filter(formatted, id==2)$loss_overall_q25,
               dplyr::filter(summarized$overall, id==2 & quantile==0.25)$loss)
})

test_that('overall loss can be formatted for writing to disk (without quantiles)', {
  to_format <- dplyr::mutate(dplyr::filter(summarized$overall, quantile==0.50), quantile=NA)
  
  formatted <- format_overall_loss(to_format)
  
  expect_named(formatted,
               c('id', 'loss_overall'))
  
  # spot-check a value
  expect_equal(dplyr::filter(formatted, id==2)$loss_overall,
               dplyr::filter(to_format, id==2)$loss)
})

test_that('loss by crop type can be formatted for writing to disk (with quantiles)', {
  formatted <- format_loss_by_type(summarized$by_type)
    
  expect_named(formatted,
               c('id', 'loss_non_food_q25', 'loss_non_food_q50', 'loss_non_food_q75', 'loss_food_q25', 'loss_food_q50', 'loss_food_q75'))
  
  # spot-check a value
  expect_equal(dplyr::filter(formatted, id==2)$loss_non_food_q75,
               dplyr::filter(summarized$by_type, id==2 & quantile==0.75 & !food)$loss)
})

test_that('loss by crop_type can be formatted for writing to disk (without quantiles)', {
  to_format <- dplyr::mutate(dplyr::filter(summarized$by_type, quantile==0.50), quantile=NA)
  
  formatted <- format_loss_by_type(to_format)
  
  expect_named(formatted,
               c('id', 'loss_non_food', 'loss_food'))
  
  # spot-check a value
  expect_equal(dplyr::filter(formatted, id==2)$loss_non_food,
               dplyr::filter(to_format, id==2 & !food)$loss)
})