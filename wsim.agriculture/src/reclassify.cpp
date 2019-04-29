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

// [[Rcpp::plugins(cpp11)]]
#include <Rcpp.h>

//' Reclassify the values in a numeric vector
//' 
//' @param x       a vector of values to reclassify
//' @param reclass a 2xN matrix with original values in the first
//'                column and reclassified values in the second 
//'                column
//' @param na_default boolean indicating whether to reclassify values
//'                   that do not appear in \code{reclass} as \code{NA},
//'                   or raise an exception
//' @return reclassified vector having the same dimensions as \code{x}
//' @export
// [[Rcpp::export]]
Rcpp::NumericVector reclassify(const Rcpp::NumericVector & x, 
                               const Rcpp::NumericMatrix & reclass,
                               bool  na_default) {
  auto n = x.size();
  auto rows = reclass.rows();
  
  if (reclass.cols() != 2) {
    Rcpp::stop("Reclassification values should be specified using a two-column matrix.");
  }
  
  bool reclass_na_to_value = false;
  double reclass_na_value;
  
  Rcpp::NumericVector x_out = Rcpp::no_init(n);
  x_out.attr("dim") = x.attr("dim");
  
  std::unordered_map<double, double> lookup;
  for (decltype(rows) j = 0; j < rows; j++) {
    if (std::isnan(reclass(j, 0)) && !std::isnan(reclass(j, 1))) {
      reclass_na_to_value = true; 
      reclass_na_value = reclass(j, 1);
    } else {
      lookup[reclass(j, 0)] = reclass(j, 1);
    }
  }
  
  for (decltype(n) i = 0; i < n; i++) {
    if (reclass_na_to_value && std::isnan(x[i])) {
      x_out[i] = reclass_na_value;
    } else {
      auto it = lookup.find(x[i]);
      if (it != lookup.end()) {
        x_out[i] = it->second;
      } else if (na_default) {
        x_out[i] = NA_REAL;
      } else {
        Rcpp::stop("No value found in reclass table for %s", x[i]);
      }
    }
  }
     
  return x_out;
}
