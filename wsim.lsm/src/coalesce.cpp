// Copyright (c) 2018-2019 ISciences, LLC.
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
using namespace Rcpp;

//' Replace NA values with a specified constant
//'
//' @param v                 a numeric vector that may
//'                          contain NA values
//' @param replacement_value a constant with with NA values
//'                          should be replaced
//'
//' @return a copy of \code{v} with NA values replaced by
//'         \code{replacement_value}
//' @export
// [[Rcpp::export]]
NumericVector coalesce(const NumericVector & v, const NumericVector & replacement_value) {
  NumericVector res = no_init(v.size());
  res.attr("dim") = v.attr("dim");

  if (replacement_value.size() == 1) {
    std::replace_copy_if(v.begin(),
                         v.end(),
                         res.begin(),
                         [](double x) { return std::isnan(x); },
                         replacement_value[0]
                         );
  } else if (replacement_value.size() == v.size()) {
    auto sz = v.size();
    for (decltype(sz) i = 0; i < sz; i++) {
      res[i] = std::isnan(v[i]) ? replacement_value[i] : v[i];
    }
  } else {
    Rcpp::stop("replacement value must be a constant or of the same size as input");
  }

  return res;
}
