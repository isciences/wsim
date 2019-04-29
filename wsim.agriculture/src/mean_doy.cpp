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

#include "mean_doy.h"
#include <Rcpp.h>
// [[Rcpp::plugins(cpp11)]]

//' Compute the mean day-of-year
//' 
//' @param x a vector representing days of the year (1-365)
//' @return the mean date
//' @export
// [[Rcpp::export]]
Rcpp::IntegerVector mean_doy(Rcpp::NumericVector x) {
  return Rcpp::IntegerVector::create(mean_doy(x.begin(), x.end()));
}
