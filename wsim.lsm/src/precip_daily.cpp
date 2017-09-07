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
IntegerVector makeWetDayList(int nDays, double pWetDays) {
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
    // TODO this is a bug.  The hardcoded 0.032 should be 1.0 / nDays.
    // Hardcoded value fails for Feb.
    pWetDays = std::max(pWetDays, 0.032);
    IntegerVector wetDays = makeWetDayList(nDays, pWetDays);
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
