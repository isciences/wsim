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

//' Generate a list of days in which precipitation occurs
//'
//' @param nDays number of days in time period
//' @param pWetDays fraction of days in which precipitation falls
//' @return A list of days in which precipitation falls, starting at 1
//' @export
// [[Rcpp::export]]
IntegerVector make_wet_day_list(int nDays, double pWetDays) {
  int wetDays = (int) std::round(nDays * pWetDays);
  std::vector<int> wetDayList;

  if (wetDays == nDays) {
    return seq(1, nDays);
  }

  double interval = nDays / (wetDays + 1.0);
  double firstDay = 1 + (int) interval/2;
  double day = firstDay;
  while(day <= nDays-interval) {
    day += interval;
    wetDayList.push_back(day);
  }

  return Rcpp::wrap(wetDayList);
}

//' Compute precipitation for each day in a multi-day period
//'
//' @param P_total total precipitation for time period
//' @param nDays number of days in time period
//' @param pWetDays fraction of days in which precipitation occurs
//' @export
// [[Rcpp::export]]
NumericVector make_daily_precip(double P_total, int nDays, double pWetDays) {
  if (pWetDays == 1.0) {
    // Total precip is evenly distributed among all days
    return Rcpp::wrap(std::vector<double>(nDays, P_total / nDays));
  } else {
    // Total precip is evenly distributed among an evenly-spaced
    // set of rainy days

    // Set a floor for pWetDays that makes sure we get at least
    // one wet day.
    pWetDays = std::max(pWetDays, 1.0 / nDays);
    IntegerVector wetDays = make_wet_day_list(nDays, pWetDays);
    double wetDayPrecip = P_total / wetDays.size();

    NumericVector dailyPrecip(nDays);

    int j = 0;
    for (int i = 0; i < dailyPrecip.size(); i++) {
      if (j < wetDays.size() && i+1 == wetDays[j]) {
        dailyPrecip[i] = wetDayPrecip;
        j++;
      } else {
        dailyPrecip[i] = 0;
      }
    }

    return dailyPrecip;
  }
}
