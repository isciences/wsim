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

//' Estimate loss due to stress (water surplus/water deficit/heat/cold)
//'
//' @param  rp       return period (positive) of stress
//' @param  rp_onset return period associated with the onset of loss
//' @param  rp_total return period associated with total loss
//' @param  power    exponent used in loss calculation; at higher values,
//'                  loss occurs at greater return periods.
//' @return loss fraction (0 to 1)
//' @export
// [[Rcpp::export]]
Rcpp::NumericVector loss_function(const Rcpp::NumericVector & rp, double rp_onset, double rp_total, double power) {
  // An earlier version of the agricultural assessment included an exponential
  // damage function that could be parameterized according to the return periods
  // associated with the onset of loss, 50% loss, and complete loss. However,
  // these parameters were taken to be constant for all types of stresses.
  // With these constant parameters, the function is equivalent to the simplified
  // power function used here. This can be changed in the future if there is a 
  // need to parameterize the loss function further.
  
  auto n = rp.size();
  Rcpp::NumericVector out = Rcpp::no_init(n);
  out.attr("dim") = rp.attr("dim");
  
  for(decltype(n) i = 0; i < n; i++) {
    if (rp[i] >= rp_total) {
      out[i] = 1;
    } else if (rp[i] <= rp_onset) {
      out[i] = 0;
    } else {
      out[i] = std::pow((rp[i] - rp_onset)/(rp_total - rp_onset), power);
    }
  }
  
  return out;
}
