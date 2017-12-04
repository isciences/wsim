#include <Rcpp.h>
using namespace Rcpp;

//' Calculate snowmelt
//'
//' Melting occurs when the temperature is greater than -1 C.
//' If elevation is less than 500 m, all snow will melt in one timestep.
//' If elevation is greater than 500m, snowmelt will be divided over
//' two timesteps.
//'
//' @param snowpack Snowpack (mm)
//' @param melt_month Number of consecutive months in which melting conditions
//'                   have been present
//' @param T Average temp (C)
//' @param z Elevation (m)
//' @return Snowmelt (mm/month)
//' @export
// [[Rcpp::export]]
NumericVector snow_melt(const NumericVector & snowpack,
                        const IntegerVector & melt_month,
                        const NumericVector & T,
                        const NumericVector & z) {
  NumericVector Sm = no_init(snowpack.size());
  Sm.attr("dim") = snowpack.attr("dim");

  for (int i = 0; i < Sm.size(); i++) {
    // Propagate NA from melt_month and elevation to Sm
    if (melt_month[i] == NA_INTEGER || std::isnan(z[i])) {
      Sm[i] = NA_REAL;
    } else if (T[i] >= -1) {
      // If we are above freezing for this timestep, then
      // either

      // (A) We're above 500m elevation and in our first
      //     month of melting, in which case half of the
      //     snow melts
      if (z[i] > 500 && melt_month[i] == 1) {
        Sm[i] = 0.5 * snowpack[i];
      }
      // Or
      // (B) All of the snow melts
      else {
        Sm[i] = snowpack[i];
      }
    } else {
      // If we are below freezing for this timestep, then
      // there is no melting.
      Sm[i] = 0.0;
    }
  }

  return Sm;
}
