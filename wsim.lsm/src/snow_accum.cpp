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
