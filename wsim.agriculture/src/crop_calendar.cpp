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
  
  Rcpp::LogicalVector res = Rcpp::no_init(n);
  res.attr("dim") = plant_date.attr("dim");
  
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
Rcpp::IntegerVector days_since_planting(const Rcpp::IntegerVector & day_of_year,
                                        const Rcpp::IntegerVector & plant_date,
                                        const Rcpp::IntegerVector & harvest_date) {
  auto n = plant_date.size();
  if (n != harvest_date.size()) {
    Rcpp::stop("Size mismatch between planting and harvest dates.");
  }
  
  Rcpp::IntegerVector res = Rcpp::no_init(n);
  res.attr("dim") = plant_date.attr("dim");
  
  if (day_of_year.size() == 1) {
    for (decltype(n) i = 0; i < n; i++) {
      res[i] = days_since_planting_impl(day_of_year[0], plant_date[i], harvest_date[i]);
    }
  } else {
    for (decltype(n) i = 0; i < n; i++) {
      res[i] = days_since_planting_impl(day_of_year[i], plant_date[i], harvest_date[i]);
    }
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
  
  Rcpp::IntegerVector res = Rcpp::no_init(n);
  res.attr("dim") = plant_date.attr("dim");
  
  for (decltype(n) i = 0; i < n; i++) {
    res[i] = days_until_harvest_impl(day_of_year, plant_date[i], harvest_date[i]);
  }
  
  return res;
}

static inline int first_growing_day_impl(int from, int to, int plant_date, int harvest_date) {
  if (plant_date <= harvest_date) {
    for (int i = from; i <= to; i++) {
      if (is_growing_season_impl(i, plant_date, harvest_date))
        return i;
    }
  } else {
    for (int i = from; i <= 365; i++) {
      if (is_growing_season_impl(i, plant_date, harvest_date))
        return i;
    }
    for (int i = 1; i <= to; i++) {
      if (is_growing_season_impl(i, plant_date, harvest_date))
        return i;
    }
  }
  
  return NA_INTEGER;
}

static inline int last_growing_day_impl(int from, int to, int plant_date, int harvest_date) {
  if (plant_date <= harvest_date) {
    for (int i = to; i >= from; i--) {
      if (is_growing_season_impl(i, plant_date, harvest_date))
        return i;
    }
  } else {
    for (int i = to; i >= 1; i--) {
      if (is_growing_season_impl(i, plant_date, harvest_date))
        return i;
    }
    for (int i = 365; i >= from; i++) {
      if (is_growing_season_impl(i, plant_date, harvest_date))
        return i;
    }
  }
  
  return NA_INTEGER;
}

//' Determine the first growing day in a range
//' 
//' @param from first day in range
//' @param to   last day in range
//' @inheritParams is_growing_season
//' @return first day between \code{from} and \code{to} that is
//'         within the growing season, or \code{NA_integer_} if no
//'         day is within the growing season.
//' @export
// [[Rcpp::export]]
Rcpp::IntegerVector first_growing_day(int from,
                                      int to,
                                      const Rcpp::IntegerVector & plant_date,
                                      const Rcpp::IntegerVector & harvest_date) {
  auto n = plant_date.size();
  if (n != harvest_date.size()) {
    Rcpp::stop("Size mismatch between planting and harvest dates.");
  }
  
  Rcpp::IntegerVector res = Rcpp::no_init(n);
  res.attr("dim") = plant_date.attr("dim");
  
  for (decltype(n) i = 0; i < n; i++) {
    res[i] = first_growing_day_impl(from, to, plant_date[i], harvest_date[i]);
  }
  
  return res;
}

//' Determine the last growing day in a range
//' 
//' @inheritParams first_growing_day
//' @return last day between \code{from} and \code{to} that is
//'         within the growing season, or \code{NA_integer_} if no
//'         day is within the growing season.
//' @export
// [[Rcpp::export]]
Rcpp::IntegerVector last_growing_day(int from,
                                     int to,
                                     const Rcpp::IntegerVector & plant_date,
                                     const Rcpp::IntegerVector & harvest_date) {
  auto n = plant_date.size();
  if (n != harvest_date.size()) {
    Rcpp::stop("Size mismatch between planting and harvest dates.");
  }
  
  Rcpp::IntegerVector res = Rcpp::no_init(n);
  res.attr("dim") = plant_date.attr("dim");
  
  for (decltype(n) i = 0; i < n; i++) {
    res[i] = first_growing_day_impl(from, to, plant_date[i], harvest_date[i]);
  }
  
  return res;
}

static int growing_days_this_season_impl(int from, int to, int plant_date, int harvest_date) {
  if (plant_date == NA_INTEGER || harvest_date == NA_INTEGER) {
    return NA_INTEGER;
  }
  
  if (plant_date > from && plant_date <= to) {
    from = plant_date;
  }
  
  if (harvest_date >= from && harvest_date <= to) {
    to = harvest_date;
  }
  
  if (is_growing_season_impl(to, plant_date, harvest_date)) {
    return to - from + 1; 
  }  
  
  return 0; 
}

static int growing_days_this_year_impl(int from, int to, int plant_date, int harvest_date) {
  if (plant_date == NA_INTEGER || harvest_date == NA_INTEGER) {
    return NA_INTEGER;
  }
  
  if (to > harvest_date) {
    to = harvest_date;
  }
    
  if (harvest_date > plant_date && from < plant_date) {
    from = plant_date;
  }
    
  return std::max(0, to - from + 1);
}

static int growing_days_next_year_impl(int from, int to, int plant_date, int harvest_date) {
  if (plant_date == NA_INTEGER || harvest_date == NA_INTEGER) {
    return NA_INTEGER;
  }
  
  if (harvest_date > plant_date) {
    return 0;
  }
  
  if (from < plant_date) {
    from = plant_date;
  }
  
  return std::max(0, to - from + 1);
}

static int days_since_planting_this_year_impl(int from, int to, int plant_date, int harvest_date) {
  if (plant_date == NA_INTEGER || harvest_date == NA_INTEGER) {
    return NA_INTEGER;
  }
  
  if (from > harvest_date) {
    return 0;
  } 
  
  if (to > harvest_date) {
    to = harvest_date;
  }
  
  if (harvest_date > plant_date) {
    return to - plant_date + 1;
  }
  
  return 365 - plant_date + 1 + to;
}

static int days_since_planting_next_year_impl(int from, int to, int plant_date, int harvest_date) {
  if (plant_date == NA_INTEGER || harvest_date == NA_INTEGER) {
    return NA_INTEGER;
  }
  
  if (harvest_date > plant_date) {
    return 0;
  }
  
  return std::max(0, to - plant_date + 1);
}

static int days_since_planting_this_season_impl(int from, int to, int plant_date, int harvest_date) {
  if (plant_date == NA_INTEGER || harvest_date == NA_INTEGER) {
    return NA_INTEGER;
  }
  
  if (plant_date < harvest_date) {
    // We have a non-wrapped growing season, with six possible configurations of 
    // test intervals:
    //
    //          P---------H
    //    AAA  BBB  CCC  DDD  EEE
    //        FFFFFFFFFFFFFFF
    if (to < plant_date || from > harvest_date) {
      // Cases A and E 
      return 0;
    }
    
    if (to > harvest_date) {
      // Convert D into C
      to = harvest_date;
    }
    
    return to - plant_date + 1;
  } else {
    // -----H       P-----
    // CCC DDD AAA BBB CCC
    //    FFFFFFFFFFFFF
    
    if (from > harvest_date && to < plant_date) {
      // Case A
      return 0;
    }
  
    if (to > plant_date) {
      return to - plant_date + 1;
    } 
    
    if (to > harvest_date) {
      to = harvest_date;
    }
    
    return (365 - plant_date + 1) + to;
  }

  return 0;
}

//' Count growing days within a day interval
//' 
//' Provide the number of growing days in the latest growing season represented
//' by the interval spanning from \code{from} to \code{to}. If \code{from} and
//' \code{to} are not in the same growing season, only the days in the same
//' growing season as \code{to} will be returned.
//' 
//' @inheritParams first_growing_day
//' 
//' @export
// [[Rcpp::export]]
Rcpp::IntegerVector growing_days_this_season(int from,
                                             int to,
                                             const Rcpp::IntegerVector & plant_date,
                                             const Rcpp::IntegerVector & harvest_date) {
  auto n = plant_date.size();
  if (n != harvest_date.size()) {
    Rcpp::stop("Size mismatch between planting and harvest dates.");
  }
  
  Rcpp::IntegerVector res = Rcpp::no_init(n);
  res.attr("dim") = plant_date.attr("dim");
  
  for (decltype(n) i = 0; i < n; i++) {
    res[i] = growing_days_this_season_impl(from, to, plant_date[i], harvest_date[i]);
  }
  
  return res;
}

//' Return the number of growing days within an interval that contribute to a harvest in the current year.
//' 
//' @inheritParams first_growing_day
//' 
//' @export
// [[Rcpp::export]]
Rcpp::IntegerVector growing_days_this_year(int from,
                                           int to,
                                           const Rcpp::IntegerVector & plant_date,
                                           const Rcpp::IntegerVector & harvest_date) {
  auto n = plant_date.size();
  if (n != harvest_date.size()) {
    Rcpp::stop("Size mismatch between planting and harvest dates.");
  }
  
  Rcpp::IntegerVector res = Rcpp::no_init(n);
  res.attr("dim") = plant_date.attr("dim");
  
  for (decltype(n) i = 0; i < n; i++) {
    res[i] = growing_days_this_year_impl(from, to, plant_date[i], harvest_date[i]);
  }
  
  return res;
}

//' Return the number of growing days within an interval that contribute to a harvest in the following year.
//' 
//' @inheritParams first_growing_day
//' 
//' @export
// [[Rcpp::export]]
Rcpp::IntegerVector growing_days_next_year(int from,
                                           int to,
                                           const Rcpp::IntegerVector & plant_date,
                                           const Rcpp::IntegerVector & harvest_date) {
  auto n = plant_date.size();
  if (n != harvest_date.size()) {
    Rcpp::stop("Size mismatch between planting and harvest dates.");
  }
  
  Rcpp::IntegerVector res = Rcpp::no_init(n);
  res.attr("dim") = plant_date.attr("dim");
  
  for (decltype(n) i = 0; i < n; i++) {
    res[i] = growing_days_next_year_impl(from, to, plant_date[i], harvest_date[i]);
  }
  
  return res;
}

//' Return the maximum number of growing days since planting that contribute to a harvest this year.
//' 
//' @inheritParams first_growing_day
//' 
//' @export
// [[Rcpp::export]]
Rcpp::IntegerVector days_since_planting_this_year(int from,
                                                  int to,
                                                  const Rcpp::IntegerVector & plant_date,
                                                  const Rcpp::IntegerVector & harvest_date) {
  auto n = plant_date.size();
  if (n != harvest_date.size()) {
    Rcpp::stop("Size mismatch between planting and harvest dates.");
  }
  
  Rcpp::IntegerVector res = Rcpp::no_init(n);
  res.attr("dim") = plant_date.attr("dim");
  
  for (decltype(n) i = 0; i < n; i++) {
    res[i] = days_since_planting_this_year_impl(from, to, plant_date[i], harvest_date[i]);
  }
  
  return res;
}

//' Return the maximum number of growing days since planting that contribute to a harvest next year.
//' 
//' @inheritParams first_growing_day
//' 
//' @export
// [[Rcpp::export]]
Rcpp::IntegerVector days_since_planting_next_year(int from,
                                                  int to,
                                                  const Rcpp::IntegerVector & plant_date,
                                                  const Rcpp::IntegerVector & harvest_date) {
  auto n = plant_date.size();
  if (n != harvest_date.size()) {
    Rcpp::stop("Size mismatch between planting and harvest dates.");
  }
  
  Rcpp::IntegerVector res = Rcpp::no_init(n);
  res.attr("dim") = plant_date.attr("dim");
  
  for (decltype(n) i = 0; i < n; i++) {
    res[i] = days_since_planting_next_year_impl(from, to, plant_date[i], harvest_date[i]);
  }
  
  return res;
}


//' Compute the maximum number of growing days between the most recent planting date
//' and a range of dates
//' 
//' @inheritParams first_growing_day
//' @export
// [[Rcpp::export]]
Rcpp::IntegerVector days_since_planting_this_season(int from,
                                                    int to,
                                                    const Rcpp::IntegerVector & plant_date,
                                                    const Rcpp::IntegerVector & harvest_date) {
  auto n = plant_date.size();
  if (n != harvest_date.size()) {
    Rcpp::stop("Size mismatch between planting and harvest dates.");
  }
  
  Rcpp::IntegerVector res = Rcpp::no_init(n);
  res.attr("dim") = plant_date.attr("dim");
  
  for (decltype(n) i = 0; i < n; i++) {
    res[i] = days_since_planting_this_season_impl(from, to, plant_date[i], harvest_date[i]);
  }
  
  return res;
}
