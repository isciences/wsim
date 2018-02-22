// Copyright (c) 2018 ISciences, LLC.
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

//' Substitute specifed values in a vector with replacements
//'
//' @param vals A vector in which some values should be replaced
//' @param subs A vector containing a sequence of replacement values,
//'             in the form val_1, replacement_1, val_2, replacement_2, ...
//'
//' @export
// [[Rcpp::export]]
NumericVector substitute(const NumericVector & vals,
                         const NumericVector & subs) {

  std::unordered_map<double, double> sub_map;
  NumericVector out(vals.size());
  out.attr("dim") = vals.attr("dim");

  for (int i = 1; i < subs.size(); i += 2) {
    sub_map[subs[i-1]] = subs[i];
  }

  std::transform(vals.cbegin(),
                 vals.cend(),
                 out.begin(),
                 [&](double val) {
                   auto lookup = sub_map.find(val);
                   if (lookup == sub_map.end()) {
                     return val;
                   } else {
                     return lookup->second;
                   }
                 });

  return out;
}
