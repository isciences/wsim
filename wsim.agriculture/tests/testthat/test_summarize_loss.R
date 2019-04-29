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

summarized <- summarize_loss(prod, loss, 'loss')

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
  formatted <- format_loss_by_crop(dplyr::rename(summarized$by_crop, lost_opportunities=loss), 'lost_opportunities')
  
  expect_named(formatted,
               c('id', 'crop', 'lost_opportunities_q25', 'lost_opportunities_q50', 'lost_opportunities_q75'))
  
  # spot-check a value
  expect_equal(dplyr::filter(formatted, id==2 & crop=='cotton')$lost_opportunities_q75,
               dplyr::filter(summarized$by_crop, id==2 & quantile==0.75 & crop=='cotton')$loss)
  
})

test_that('per-crop loss can be formatted for writing to disk (without quantiles)', {
  to_format <- dplyr::rename(dplyr::mutate(dplyr::filter(summarized$by_crop, quantile==0.50), quantile=NA), perte=loss)
  formatted <- format_loss_by_crop(to_format, 'perte')
  
  expect_named(formatted,
               c('id', 'crop', 'perte'))
  
  # spot-check a value
  expect_equal(dplyr::filter(formatted, id==2 & crop=='cotton')$perte,
               dplyr::filter(summarized$by_crop, id==2 & quantile==0.5 & crop=='cotton')$loss)
  
})

test_that('overall loss can be formatted for writing to disk (with quantiles)', {
  formatted <- format_overall_loss(dplyr::rename(summarized$overall, lozz=loss), 'lozz')
  
  expect_named(formatted,
               c('id', 'lozz_overall_q25', 'lozz_overall_q50', 'lozz_overall_q75'))
  
  # spot-check a value
  expect_equal(dplyr::filter(formatted, id==2)$lozz_overall_q25,
               dplyr::filter(summarized$overall, id==2 & quantile==0.25)$loss)
})

test_that('overall loss can be formatted for writing to disk (without quantiles)', {
  to_format <- dplyr::rename(dplyr::mutate(dplyr::filter(summarized$overall, quantile==0.50), quantile=NA), lox=loss)
  
  formatted <- format_overall_loss(to_format, 'lox')
  
  expect_named(formatted,
               c('id', 'lox_overall'))
  
  # spot-check a value
  expect_equal(dplyr::filter(formatted, id==2)$lox_overall,
               dplyr::filter(to_format, id==2)$lox)
})

test_that('loss by crop type can be formatted for writing to disk (with quantiles)', {
  formatted <- format_loss_by_type(dplyr::rename(summarized$by_type, Z=loss), 'Z')
    
  expect_named(formatted,
               c('id', 'Z_non_food_q25', 'Z_non_food_q50', 'Z_non_food_q75', 'Z_food_q25', 'Z_food_q50', 'Z_food_q75'))
  
  # spot-check a value
  expect_equal(dplyr::filter(formatted, id==2)$Z_non_food_q75,
               dplyr::filter(summarized$by_type, id==2 & quantile==0.75 & !food)$loss)
})

test_that('loss by crop_type can be formatted for writing to disk (without quantiles)', {
  to_format <- dplyr::rename(dplyr::mutate(dplyr::filter(summarized$by_type, quantile==0.50), quantile=NA), Y=loss)
  
  formatted <- format_loss_by_type(to_format, 'Y')
  
  expect_named(formatted,
               c('id', 'Y_non_food', 'Y_food'))
  
  # spot-check a value
  expect_equal(dplyr::filter(formatted, id==2)$Y_non_food,
               dplyr::filter(to_format, id==2 & !food)$Y)
})