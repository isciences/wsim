// Copyright (c) 2019 ISciences, LLC.
// All rights reserved.
//
// WSIM is licensed under the Apache License, Version 2.0 (the "License").
// You may not use this file except in compliance with the License. You may
// obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0.
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#include <Rcpp.h>
#include <cmath>
// [[Rcpp::plugins(cpp11)]]

static inline decltype(NA_LOGICAL)
  is_growing_season_impl(int day_of_year, int plant_date, int harvest_date) {
    if (Rcpp::IntegerVector::is_na(harvest_date) ||
        Rcpp::IntegerVector::is_na(plant_date)) {
      return NA_LOGICAL;
    } else if (harvest_date > plant_date) {
      return day_of_year >= plant_date && day_of_year <= harvest_date;
    } else {
      return day_of_year >= plant_date || day_of_year <= harvest_date;
    }
}

//' Determine if a given day is within the growing season
//' 
//' @param day_of_year  numerical day of year, 1-365
//' @param plant_date   day of year when planting occurs
//' @param harvest_date day of year when harvest occurs
//' @return            TRUE if day is within growing season, FALSE otherwise
//' @export
// [[Rcpp::export]]
Rcpp::LogicalVector is_growing_season(int day_of_year,
                                      const Rcpp::IntegerVector & plant_date,
                                      const Rcpp::IntegerVector & harvest_date) {
  auto n = plant_date.size();
  if (n != harvest_date.size()) {
    Rcpp::stop("Size mismatch between planting and harvest dates.");
  }
  
  Rcpp::LogicalVector res = Rcpp::no_init(plant_date.size());
  for (decltype(n) i = 0; i < n; i++) {
    res[i] = is_growing_season_impl(day_of_year, plant_date[i], harvest_date[i]);
  }
  
  return res;
}

static inline int days_since_planting_impl(int day_of_year, int plant_date, int harvest_date) {
  if (Rcpp::IntegerVector::is_na(plant_date) || Rcpp::IntegerVector::is_na(harvest_date)) {
    return NA_INTEGER;
  } else if (!is_growing_season_impl(day_of_year, plant_date, harvest_date)) {
    return NA_INTEGER;
  } else if (harvest_date > plant_date || day_of_year >= plant_date) {
    return day_of_year - plant_date;
  } else {
    return 365 - plant_date + day_of_year;
  }
}

//' Determine the number of days since planting
//' 
//' @inheritParams is_growing_season
//' @return number of days since planting or \code{NA_integer_} if 
//'         \code{day_of_year} is outside the growing season.
//' @export
// [[Rcpp::export]]
Rcpp::IntegerVector days_since_planting(int day_of_year,
                                        const Rcpp::IntegerVector & plant_date,
                                        const Rcpp::IntegerVector & harvest_date) {
  auto n = plant_date.size();
  if (n != harvest_date.size()) {
    Rcpp::stop("Size mismatch between planting and harvest dates.");
  }
  
  Rcpp::IntegerVector res = Rcpp::no_init(plant_date.size());
  
  for (decltype(n) i = 0; i < n; i++) {
    res[i] = days_since_planting_impl(day_of_year, plant_date[i], harvest_date[i]);
  }
  
  return res;
}

static inline int days_until_harvest_impl(int day_of_year, int plant_date, int harvest_date) {
  if (Rcpp::IntegerVector::is_na(plant_date) || Rcpp::IntegerVector::is_na(harvest_date)) {
    return NA_INTEGER;
  } else if (!is_growing_season_impl(day_of_year, plant_date, harvest_date)) {
    return NA_INTEGER;
  } else if (harvest_date > plant_date || day_of_year <= harvest_date) {
    return harvest_date - day_of_year;
  } else {
    return 365 - day_of_year + harvest_date;
  }
}

//' Determine the number of days until harvest
//' 
//' @inheritParams is_growing_season
//' @return number of days until harvest or \code{NA_integer_} if 
//'         \code{day_of_year} is outside the growing season.
//' @export
// [[Rcpp::export]]
Rcpp::IntegerVector days_until_harvest(int day_of_year,
                                       const Rcpp::IntegerVector & plant_date,
                                       const Rcpp::IntegerVector & harvest_date) {
  auto n = plant_date.size();
  if (n != harvest_date.size()) {
    Rcpp::stop("Size mismatch between planting and harvest dates.");
  }
  
  Rcpp::IntegerVector res = Rcpp::no_init(plant_date.size());
  
  for (decltype(n) i = 0; i < n; i++) {
    res[i] = days_until_harvest_impl(day_of_year, plant_date[i], harvest_date[i]);
  }
  
  return res;
}
