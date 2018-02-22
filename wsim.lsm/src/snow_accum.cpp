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

#include <Rcpp.h>
using namespace Rcpp;

//' Snow accumulation
//'
//' Compute snow accumulation, assuming that all precipitation
//' is snowfall if the temperature less than -1 C, and that no
//' precipitation is snowfall if the temperature is unknown or
//' greater than or equal to -1 C.
//'
//' @param Pr Measured precipitation (mm/day)
//' @param T  Average daily temperature (C)
//' @return snow accumulation in mm
//' @export
// [[Rcpp::export]]
NumericVector snow_accum(const NumericVector & Pr, const NumericVector & T) {
  NumericVector Sa = no_init(Pr.size());
  Sa.attr("dim") = Pr.attr("dim");

  for (int i = 0; i < Sa.size(); i++) {
    Sa[i] = T[i] <= -1 ? Pr[i] : 0.0;
  }

  return Sa;
}
