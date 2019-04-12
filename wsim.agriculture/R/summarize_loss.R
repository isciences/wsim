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

#' Summarize losses for each geography, given data frames of production and loss
#' 
#' @param production data frame of production data, having columns: \itemize{
#'                     \item id
#'                     \item method
#'                     \item crop
#'                     \item subcrop
#'                     \item production }
#' @param loss data frame of loss data, having columns: \itemize{
#'                     \item id
#'                     \item method
#'                     \item crop
#'                     \item subcrop
#'                     \item quantile
#'                     \item `loss_var` }
#' @param loss_var name of loss variable to aggregated
#' @return a list of three data frames summarizing losses for each region by crop, by crop type (food/non-food), and overall.
#'
#' @export
summarize_loss <- function(production, loss, loss_var) {
  loss_var <- rlang::sym(loss_var)
  
  df <- dplyr::inner_join(production, loss, by=c('id', 'method', 'subcrop', 'crop'))
  df <- dplyr::inner_join(df, dplyr::select(wsim_crops, crop=wsim_name, food), by='crop')
  
  overall <- dplyr::summarize(dplyr::group_by(df, id, quantile),
                              !!rlang::sym(loss_var) := ifelse(sum(production) > 0, sum(!!loss_var)/sum(production), NA_real_),
                              production=sum(production))
  
  by_crop <- dplyr::summarize(dplyr::group_by(dplyr::select(df, -food), id, crop, quantile),
                              !!rlang::sym(loss_var) := ifelse(sum(production) > 0, sum(!!loss_var)/sum(production), NA_real_),
                              production=sum(production))
  
  by_type <- dplyr::summarize(dplyr::group_by(df, id, food, quantile),
                              !!rlang::sym(loss_var) := ifelse(sum(production) > 0, sum(!!loss_var)/sum(production), NA_real_),
                              production=sum(production))
  
  list(
    by_crop= by_crop,
    by_type= by_type,
    overall=overall
  )
}

#' Format data frame of losses by crop for writing to disk
#' 
#' @param df data frame returned by \code{summarize_loss}
#' @param loss_var name of loss variable in \code{df}
#' @return data frame that can be passed to \code{write_vars_to_cdf}
#' @export
format_loss_by_crop <- function(df, loss_var) {
  if (all(is.na(df$quantile))) {
    dplyr::select(df, crop, !!rlang::sym(loss_var))
  } else {
    tidyr::pivot_wider(
      dplyr::mutate(df, quantile=sprintf('q%d', quantile*100)),
      id_cols=c(id, crop),
      names_from=quantile,
      values_from=!!rlang::sym(loss_var),
      names_prefix=paste0(loss_var, '_')
    )
  }
}

#' Format data frame of overall losses for writing to disk
#' 
#' @param df data frame returned by \code{summarize_loss}
#' @param loss_var name of loss variable in \code{df}
#' @return data frame that can be passed to \code{write_vars_to_cdf}
#' @export
format_overall_loss <- function(df, loss_var) {
  if (all(is.na(df$quantile))) {
    dplyr::select(df, !!rlang::sym(paste0(loss_var, '_overall')):=!!rlang::sym(loss_var))
  } else {
    tidyr::pivot_wider(
      dplyr::mutate(df, quantile=sprintf('q%d', quantile*100)),
      id_cols=id,
      names_from=quantile,
      values_from=loss_var,
      names_prefix=paste0(loss_var, '_overall_')
    )
  }
}

#' Format data frame of losses by type for writing to disk
#' 
#' @param df data frame returned by \code{summarize_loss}
#' @param loss_var name of loss variable in \code{df}
#' @return data frame that can be passed to \code{write_vars_to_cdf}
#' @export
format_loss_by_type <- function(df, loss_var) {
  if (all(is.na(df$quantile))) {
    tidyr::pivot_wider(
      dplyr::mutate(df,
                    type=ifelse(food, 'food', 'non_food')),
      id_cols=id,
      names_from=type,
      values_from=loss_var,
      names_prefix=paste0(loss_var, '_')
    )
  } else {
    tidyr::pivot_wider(
      dplyr::mutate(df, 
                    quantile=sprintf('q%d', quantile*100),
                    type=ifelse(food, 'food', 'non_food')),
      id_cols=id,
      names_from=c(type, quantile),
      values_from=loss_var,
      names_prefix=paste0(loss_var, '_'))
  }
}
